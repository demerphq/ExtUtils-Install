use strict;
use Module::Build;
use lib qw(lib);

# On Win32 things work better if Win32API::File is available.
# Activestate builds have it by default, but the core distro doesn't
# so we recommend it on Win32.
#
# * BUT *
#
# We can't recommend it on the release system as it then goes in the YAML.pl
# and then non-Win32 CPAN clients think they need it get upset when it fails
# to build on their system.
#
# Until CPAN and Module::Build and the other infrastructure has a better
# way to deal with this we assume UNIX when building a release.
#
# The pre-build stage will moan on Win32 anyway.

my $Recommend_Win32API_File =  $ENV{USERNAME} ne 'demerphq'
                            && ($^O eq 'MSWin32' || $^O eq 'cygwin');


my $builder = Module::Build->new(
    module_name         => 'ExtUtils::Install',
    license             => 'perl',
    dist_name           => 'ExtUtils-Install',
    dist_author         => 'demerphq <yves@cpan.org>',
    dist_version_from   => 'lib/ExtUtils/Install.pm',
    dynamic_config      => 1,

    installdirs         => 'core',

    build_requires => {
#       'Test::More' => 0, # This is bundled, but not in @INC for prereqs
    },

    requires => {
        'perl' => '5.006',
#        'vars' => 0,

#        'AutoSplit' => 0,
#        'Exporter' => 0,

        'Carp' => 0,
#        'Config' => 0,

        'Cwd' => 0,

        'File::Basename' => 0,
        'File::Compare' => 0,
        'File::Copy' => 0,
        'File::Find' => 0,
        'File::Path' => 0,
        'File::Spec' => 0,

        ($^O eq 'VMS' ? ('VMS::Filespec' => 0) : ()),

        'ExtUtils::MakeMaker' => 0,
    },

    recommends => {
        ($Recommend_Win32API_File ? ('Win32API::File' => 0) : ()),
    },
);

$builder->create_build_script();
