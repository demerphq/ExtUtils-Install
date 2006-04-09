use 5.00503;
use strict;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'ExtUtils::Install',
    AUTHOR              => 'demerphq <yves@cpan.org>',
    VERSION_FROM        => 'lib/ExtUtils/Install.pm',
    ABSTRACT_FROM       => 'lib/ExtUtils/Install.pm',
    DISTNAME            => 'ex-ExtUtils-Install',
    PL_FILES            => {}, # Avoid auto extracting 'Build.PL'

    PREREQ_PM => {
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
        ($^O eq 'MSWin32' ? ('Win32API::File' => 0) : ()),

        'ExtUtils::MakeMaker' => 0,
        'ExtUtils::MM' => 0, # for parse_version; rework it ???

        'Test::More' => 0,
    },

    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'ExtUtils-Install-*' },
);
