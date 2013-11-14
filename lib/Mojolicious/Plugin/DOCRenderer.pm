package Mojolicious::Plugin::DOCRenderer;
use Mojo::Base 'Mojolicious::Plugin';

use File::Basename 'dirname';
use File::Spec::Functions 'catdir';
use Mojo::Asset::File;
use Mojo::ByteStream 'b';
use Mojo::DOM;
use Mojo::Util 'url_escape';
use Pod::Simple::HTML;
use Pod::Simple::Search;

our $VERSION = '3.02';

# Paths
my @PATHS = map { $_, "$_/pods" } @INC;

# "Futurama - The One Bright Spot in Your Life!"
sub register {
  my ($self, $app, $conf) = @_;

  # Add "doc" handler
  my $preprocess = $conf->{preprocess} || 'ep';
  $app->renderer->add_handler(
    $conf->{name} || 'doc' => sub {
      my ($r, $c, $output, $options) = @_;

      # Preprocess and render
      return unless $r->handlers->{$preprocess}->($r, $c, $output, $options);
      $$output = _pod_to_html($$output);
      return 1;
    }
  );

  # Append "templates" and "public" directories
  my $base = catdir(dirname(__FILE__), 'DOCRenderer');
  push @{$app->renderer->paths}, catdir($base, 'templates');

  # Doc
  my $url    = $conf->{url}    || '/doc';
  my $module = $conf->{module} || $ENV{MOJO_APP};
  return $app->routes->any(
    "$url/*module" => {url => $url, module => $module} => \&_doc);
}

sub _doc {
  my $self = shift;

  # Find module
  my $module = $self->param('module');
  $module =~ s!/!\:\:!g;
  my $path = Pod::Simple::Search->new->find($module, @PATHS);

  # Redirect to CPAN
  return $self->redirect_to("http://metacpan.org/module/$module")
    unless $path && -r $path;

  # Turn POD into HTML
  open my $file, '<', $path;
  my $html = _pod_to_html(join '', <$file>);

  # Rewrite links
  my $dom = Mojo::DOM->new("$html");
  my $doc = $self->url_for( $self->param('url') . '/' );
  $dom->find('a[href]')->each(
    sub {
      my $attrs = shift->attr;
      $attrs->{href} =~ s!%3A%3A!/!gi
        if $attrs->{href} =~ s!^http\://search\.cpan\.org/perldoc\?!$doc!;
    }
  );

  # Rewrite code blocks for syntax highlighting
  $dom->find('pre')->each(
    sub {
      my $e = shift;
      return if $e->all_text =~ /^\s*\$\s+/m;
      my $attrs = $e->attr;
      my $class = $attrs->{class};
      $attrs->{class} = defined $class ? "$class prettyprint" : 'prettyprint';
    }
  );

  # Rewrite headers
  my $url = $self->req->url->clone;
  my (%anchors, @parts);
  $dom->find('h1, h2, h3')->each(
    sub {
      my $e = shift;

      # Anchor and text
      my $name = my $text = $e->all_text;
      $name =~ s/\s+/_/g;
      $name =~ s/\W//g;
      my $anchor = $name;
      my $i      = 1;
      $anchor = $name . $i++ while $anchors{$anchor}++;

      # Rewrite
      push @parts, [] if $e->type eq 'h1' || !@parts;
      push @{$parts[-1]}, $text, $url->fragment($anchor)->to_abs;
      $e->replace_content(
        $self->link_to(
          $text => $url->fragment('toc')->to_abs,
          class => 'mojoscroll',
          id    => $anchor
        )
      );
    }
  );

  # Try to find a title
  my $title = 'Doc';
  $dom->find('h1 + p')->first(sub { $title = shift->text });

  # Combine everything to a proper response
  $self->content_for(doc => "$dom");
  $self->render(template => 'doc', title => $title, parts => \@parts);
  $self->res->headers->content_type('text/html;charset="UTF-8"');
}

sub _pod_to_html {
  return unless defined(my $pod = shift);

  # Block
  $pod = $pod->() if ref $pod eq 'CODE';

  # Parser
  my $parser = Pod::Simple::HTML->new;
  $parser->force_title('');
  $parser->html_header_before_title('');
  $parser->html_header_after_title('');
  $parser->html_footer('');

  # Parse
  $parser->output_string(\(my $output));
  return $@ unless eval { $parser->parse_string_document("$pod"); 1 };

  # Filter
  $output =~ s!<a name='___top' class='dummyTopAnchor'\s*?></a>\n!!g;
  $output =~ s!<a class='u'.*?name=".*?"\s*>(.*?)</a>!$1!sg;

  return $output;
}

1;

__END__

=head1 NAME

Mojolicious::Plugin::DOCRenderer - Doc Renderer Plugin

=head1 SYNOPSIS

  # Mojolicious::Lite
  plugin 'DOCRenderer';
  plugin DOCRenderer => {module => 'MyApp'};
  plugin DOCRenderer => {name => 'foo'};
  plugin DOCRenderer => {url => '/mydoc'};
  plugin DOCRenderer => {preprocess => 'epl'};

  # Mojolicious
  $self->plugin('DOCRenderer');
  $self->plugin(DOCRenderer => {module => 'MyApp'});
  $self->plugin(DOCRenderer => {name => 'foo'});
  $self->plugin(DOCRenderer => {url => '/mydoc'});
  $self->plugin(DOCRenderer => {preprocess => 'epl'});

  #############################
  # Mojolicious::Lite example #
  #############################
  use Mojolicious::Lite;
  use File::Basename;

  plugin 'DOCRenderer' => {
      # use this script base name as a default module to show for "/doc"
      module => fileparse( __FILE__, qr/\.[^.]*/ );
  };

  app->start;

  __END__

  =head1 NAME

  MyApp - My Mojolicious::Lite Application

  =head1 DESCRIPTION

  This documentation will be available online, for example from L<http://localhost:3000/doc>.

  =cut

  #######################
  # Mojolicious example #
  #######################
  package MyApp;
  use Mojo::Base 'Mojolicious';

  sub development_mode {
    # Enable browsing of "/doc" only in development mode
    shift->plugin( 'DOCRenderer' );
  }

  sub startup {
    my $self = shift;
    # some code
  }

  __END__

  =head1 NAME

  MyApp - My Mojolicious Application

  =head1 DESCRIPTION

  This documentation will be available online, for example from L<http://localhost:3000/doc>.

  =cut

=head1 DESCRIPTION

L<Mojolicious::Plugin::DOCRenderer> generates on-the-fly and browses online
POD documentation directly from your Mojolicious application source codes
and makes it available under I</doc> (customizable).

The plugin expects that you use POD to document your codes of course.

The plugin is simple modification of L<Mojolicious::Plugin::PODRenderer>.

=head1 OPTIONS

=head2 C<module>

  # Mojolicious::Lite
  plugin DOCRenderer => {module => 'MyApp'};

Name of the module to initially display. Default is C<$ENV{MOJO_APP}>.
Mojolicious::Lite application may have undefined C<$ENV{MOJO_APP}>; in such
case you should set C<module>, see Mojolicious::Lite example.

=head2 C<name>

  # Mojolicious::Lite
  plugin DOCRenderer => {name => 'foo'};

Handler name.

=head2 C<preprocess>

  # Mojolicious::Lite
  plugin DOCRenderer => {preprocess => 'epl'};

Handler name of preprocessor.

=head2 C<url>

  # Mojolicious::Lite
  plugin DOCRenderer => {url => '/mydoc'};

URL from which the documentation of your project is available. Default is I</doc>.

=head1 METHODS

L<Mojolicious::Plugin::DOCRenderer> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 C<register>

  my $route = $plugin->register(Mojolicious->new);
  my $route = $plugin->register(Mojolicious->new, {name => 'foo'});

Register renderer in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious::Plugin::PODRenderer>, L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
