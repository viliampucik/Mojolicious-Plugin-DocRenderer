#!/usr/bin/env perl

use Test::More tests => 1;

BEGIN {
    use_ok( 'Mojolicious::Plugin::DocRenderer' ) || print "Bail out!
";
}

diag( "Testing Mojolicious::Plugin::DocRenderer $Mojolicious::Plugin::DocRenderer::VERSION, Perl $], $^X" );
