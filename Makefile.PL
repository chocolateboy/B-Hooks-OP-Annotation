use 5.008000;

use strict;
use warnings;

use ExtUtils::MakeMaker;
use Config;

my $optimize;

if ($Config{gccversion}) {
    $optimize = '-O3 -Wall';
} elsif ($Config{osname} eq 'MSWin32') {
    $optimize = '-O2 -W4';
} else {
    $optimize = $Config{optimize};
}

my $MAKEFILE_VARS = eval {
    require ExtUtils::Depends;

    my $package = ExtUtils::Depends->new('B::Hooks::OP::Annotation');

    $package->install('hook_op_annotation.h');
    $package->add_xs('Annotation.xs');
    $package->add_pm('lib/B/Hooks/OP/Annotation.pm' => '$(INST_LIB)/B/Hooks/OP/Annotation.pm');
    $package->save_config('Files.pm');

    my %vars = $package->get_makefile_vars();
    my $clean = $vars{clean};

    $clean->{FILES} .= ' Files.pm' if ($clean);

    \%vars;
} || {};

warn $@ if ($@);

WriteMakefile(
    NAME          => 'B::Hooks::OP::Annotation',
    VERSION_FROM  => 'lib/B/Hooks/OP/Annotation.pm',
    PREREQ_PM     => { 'ExtUtils::Depends' => '0.301' },
    ABSTRACT_FROM => 'lib/B/Hooks/OP/Annotation.pm',
    AUTHOR        => 'chocolateboy <chocolate@cpan.org>',
    LIBS          => [''],
    DEFINE        => '',
    INC           => '-I.',
    OPTIMIZE      => $optimize,
    ($ExtUtils::MakeMaker::VERSION >= 6.31 ? (LICENSE => 'perl') : ()),
    FUNCLIST      => [ qw(op_annotation_group_new op_annotation_new op_annotation_group_free op_annotation_free) ],
    DL_FUNCS      => { 'B::Hooks::OP::Annotation' => [] },
    %$MAKEFILE_VARS
);
