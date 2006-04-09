use strict;

use Module::Build;

my $Recommend_Win32API_File = ($^O eq 'MSWin32' || $^O eq 'cygwin');

my $builder = Module::Build->new(
    module_name         => 'ExtUtils::Install',
    license             => 'perl',
    dist_name           => 'ExtUtils-Install',
    dist_author         => 'demerphq <yves@cpan.org>',
    dist_version_from   => 'lib/ExtUtils/Install.pm',

    build_requires => {
#       'Test::More' => 0, # This is bundled, but not in @INC for prereqs
    },

    requires => {
        'perl' => '5.005_03',
        'vars' => 0,

        'AutoSplit' => 0,
        'Exporter' => 0,

        'Carp' => 0,
        'Config' => 0,

        'Cwd' => 0,

        'File::Basename' => 0,
        'File::Compare' => 0,
        'File::Copy' => 0,
        'File::Find' => 0,
        'File::Path' => 0,
        'File::Spec' => 0,

        ($^O eq 'VMS' ? ('VMS::Filespec' => 0) : ()),

        'ExtUtils::MakeMaker' => 0,
        'ExtUtils::MM' => 0, # for parse_version; rework it ???
    },

    recommends => {
        ($Recommend_Win32API_File ? ('Win32API::File' => 0) : ()),
    },
);

$builder->create_build_script();
