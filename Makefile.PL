use 5.010001;

use strict;
use warnings;

use ExtUtils::MakeMaker;

my ($mm) = $ExtUtils::MakeMaker::VERSION =~ /^([^_]+)/;

WriteMakefile(
  NAME         => 'Mojolicious::Plugin::DOCRenderer',
  VERSION_FROM => 'lib/Mojolicious/Plugin/DOCRenderer.pm',
  ABSTRACT     => 'Browses online documentation of your Mojolicious application',
  AUTHOR       => 'Viliam Pucik <viliam.pucik@gmail.com>',

  ($mm < 6.3002 ? () : ('LICENSE' => 'artistic_2')),

  ( $mm < 6.46
    ? ()
    : (
      META_MERGE => {
        requires  => {perl => '5.010001'},
        resources => {
          homepage    => 'https://github.com/viliampucik/Mojolicious-Plugin-DocRenderer',
          license     => 'http://dev.perl.org/licenses/',
          repository  => 'git://github.com/viliampucik/Mojolicious-Plugin-DocRenderer.git',
        },
        no_index => {directory => [qw/t/]}
      },
      META_ADD => {
        build_requires     => {},
        configure_requires => {}
      },
    )
  ),

  PREREQ_PM    => { 'Mojolicious' => '2.48' },
  test         => { TESTS => 't/*.t' }
);
