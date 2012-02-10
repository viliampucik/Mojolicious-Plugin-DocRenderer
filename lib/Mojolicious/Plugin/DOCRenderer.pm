package Mojolicious::Plugin::DOCRenderer;
use Mojo::Base 'Mojolicious::Plugin';

use IO::File;
use Mojo::Asset::File;
use Mojo::ByteStream 'b';
use Mojo::DOM;
use Mojo::Util 'url_escape';
use Pod::Simple::HTML;
use Pod::Simple::Search;

our $VERSION = '2.00';

# Bundled files
our $PERLDOC = $Mojolicious::Controller::H->slurp_rel_file('perldoc.html.ep');

# "Futurama - The One Bright Spot in Your Life!"
sub register {
  my ($self, $app, $conf) = @_;

  # Config
  $conf ||= {};
  my $app_module = $conf->{module}     || $ENV{MOJO_APP};
  my $name       = $conf->{name}       || 'doc';
  my $preprocess = $conf->{preprocess} || 'ep';
  my $url        = $conf->{url}        || '/doc';

  # Add "pod" handler
  $app->renderer->add_handler(
    $name => sub {
      my ($r, $c, $output, $options) = @_;

      # Preprocess with ep and then render
      $$output = _pod_to_html($$output)
        if $r->handlers->{$preprocess}->($r, $c, $output, $options);
    }
  );

  # Perldoc
  $app->routes->any(
    "$url/(*module)" => {module => $app_module} => sub {
      my $self = shift;

      # Find module
      my $module = $self->param('module');
      $module =~ s|/|\:\:|g;
      my $path = Pod::Simple::Search->new->find($module, @INC);

      # Redirect to CPAN
      return $self->redirect_to("http://metacpan.org/module/$module")
        unless $path && -r $path;

      # Turn POD into HTML
      my $file = IO::File->new("< $path");
      my $html = _pod_to_html(join '', <$file>);

      # Rewrite links
      my $dom = Mojo::DOM->new("$html");
      my $doc = $self->url_for("$url/");
      $dom->find('a[href]')->each(
        sub {
          my $attrs = shift->attrs;
          $attrs->{href} =~ s|%3A%3A|/|gi
            if $attrs->{href}
              =~ s|^http\://search\.cpan\.org/perldoc\?|$doc|;
        }
      );

      # Rewrite code sections for syntax highlighting
      $dom->find('pre')->each(
        sub {
          return if (my $e = shift)->all_text =~ /^\s*\$\s+/m;
          my $attrs = $e->attrs;
          my $class = $attrs->{class};
          $attrs->{class} =
            defined $class ? "$class prettyprint" : 'prettyprint';
        }
      );

      # Rewrite headers
      my $url = $self->req->url->clone;
      $url =~ s|%2F|/|gi;
      my $sections = [];
      $dom->find('h1, h2, h3')->each(
        sub {
          my $e = shift;
          my $anchor = my $text = $e->all_text;
          $anchor =~ s/\s+/_/g;
          $anchor = url_escape $anchor, 'A-Za-z0-9_';
          $anchor =~ s/\%//g;
          push @$sections, [] if $e->type eq 'h1' || !@$sections;
          push @{$sections->[-1]}, $text, $url->fragment($anchor)->to_abs;
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
      $self->content_for(perldoc => "$dom");
      $self->render(
        inline   => $PERLDOC,
        title    => $title,
        sections => $sections
      );
      $self->res->headers->content_type('text/html;charset="UTF-8"');
    }
  ) unless $conf->{no_doc};
}

sub _pod_to_html {
  my $pod = shift;
  return unless defined $pod;

  # Block
  $pod = $pod->() if ref $pod eq 'CODE';

  # Parser
  my $parser = Pod::Simple::HTML->new;
  $parser->force_title('');
  $parser->html_header_before_title('');
  $parser->html_header_after_title('');
  $parser->html_footer('');

  # Parse
  my $output;
  $parser->output_string(\$output);
  eval { $parser->parse_string_document("$pod") };
  return $@ if $@;

  # Filter
  $output =~ s|<a name='___top' class='dummyTopAnchor'\s*?></a>\n||g;
  $output =~ s|<a class='u'.*?name=".*?"\s*>(.*?)</a>|$1|sg;

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

=head2 C<no_doc>

  # Mojolicious::Lite
  plugin DOCRenderer => {no_doc => 1};

Disable doc browser.
Note that this option is EXPERIMENTAL and might change without warning!

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

  $plugin->register;

Register renderer in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious::Plugin::PODRenderer>, L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
