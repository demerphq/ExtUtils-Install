BEGIN { require 5.006; }
use strict;

use lib qw(lib); # use ourself if possible not the existing stuff.

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

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'ExtUtils::Install',
    AUTHOR              => 'demerphq <yves@cpan.org>',
    VERSION_FROM        => 'lib/ExtUtils/Install.pm',
    ABSTRACT            => 'install files from here to there',

#   This causes failure to locate ABSTRACT with DISTNAME below set to different name
#   ABSTRACT_FROM       => 'lib/ExtUtils/Install.pm',

    DISTNAME            => 'ExtUtils-Install',
    PL_FILES            => {}, # Avoid auto extracting 'Build.PL'

    PREREQ_PM => {
#        'vars' => 0,

#       'AutoSplit' => 0,
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
        ($Recommend_Win32API_File ? ('Win32API::File' => 0) : ()),

        'ExtUtils::MakeMaker' => 0,

#       'Test::More' => 0, # This is bundled, but not in @INC for prereqs
    },

    INSTALLDIRS     => 'perl', # install into site not into lib.
    
    #NO_META => 1,

    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'ExtUtils-Install-*' },
);

{
    package MY;

    my($lib);
    BEGIN {
        $lib  = File::Spec->canonpath('lib/');
    }

    # Make sure PERLRUN uses the MakeMaker about to be installed
    # and not the currently installed one.
    sub init_PERL {
        my($self) = shift;
        $self->SUPER::init_PERL;
        $self->{ABSPERLRUN} .= qq{ "-I$lib"};
        $self->{PERLRUN} .= qq{ "-I$lib"};
        $self->{FULLPERLRUN} .= qq{ "-I$lib"};
    }
}
