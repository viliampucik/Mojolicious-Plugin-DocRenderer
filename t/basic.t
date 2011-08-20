#!/usr/bin/env perl
use Mojo::Base -strict;

use lib './';
use lib './t';
use lib './lib';
use lib '../lib';

# Disable Bonjour, IPv6 and libev
BEGIN {
  $ENV{MOJO_NO_BONJOUR} = $ENV{MOJO_NO_IPV6} = 1;
  $ENV{MOJO_IOWATCHER} = 'Mojo::IOWatcher';
}

use Test::More;
plan skip_all => 'Perl 5.10 or Pod::Simple required for this test!'
  unless eval { require Pod::Simple::HTML; 1 };
plan tests => 9;

use Mojolicious::Lite;
use File::Basename;
use Test::Mojo;

my $module = fileparse( __FILE__, qr/\.pl/ );

# DOC renderer plugin
plugin 'DOCRenderer' => {
    module => $module,
};

# app->start;
my $t = Test::Mojo->new;

$t->get_ok('/doc')
    ->status_is(200)
    ->content_like(qr/It works!/);
$t->get_ok("/doc/$module")
    ->status_is(200)
    ->content_like(qr/It works!/);
$t->get_ok("/doc/Mojolicious/Plugin/DOCRenderer")
    ->status_is(200)
    ->content_like(qr/DOCRenderer/);

__END__

=head1 NAME

MyApp - My Mojolicious Application

=head1 DESCRIPTION

It works!

=cut
