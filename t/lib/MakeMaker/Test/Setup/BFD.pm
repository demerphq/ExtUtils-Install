package MakeMaker::Test::Setup::BFD;

@ISA = qw(Exporter);
require Exporter;
@EXPORT = qw(setup_recurs teardown_recurs);

use strict;
use File::Path;
use File::Basename;
use MakeMaker::Test::Utils;

my $Is_VMS = $^O eq 'VMS';

sub clean { my $str=shift; $str=~s/^##//mg; $str }

my %Files = (
             'Big-Dummy/Makefile.PL'          => clean(<<'END'),
##use ExtUtils::MakeMaker;
##
### This will interfere with the PREREQ_PRINT tests.
##printf "Current package is: %s\n", __PACKAGE__ unless "@ARGV" =~ /PREREQ/;
##
##WriteMakefile(
##    NAME          => 'Big::Dummy',
##    VERSION_FROM  => 'lib/Big/Dummy.pm',
##    EXE_FILES     => [qw(bin/program)],
##    PREREQ_PM     => { strict => 0 },
##    ABSTRACT_FROM => 'lib/Big/Dummy.pm',
##    AUTHOR        => 'Michael G Schwern <schwern@pobox.com>',
##);
END

             'Big-Dummy/INSTALL.SKIP'     => clean(<<'END'),
##\.SKIP$
END

             'Big-Dummy/bin/program'          => clean(<<'END'),
###!/usr/bin/perl -w
##
##=head1 NAME
##
##program - this is a program
##
##=cut
##
##1;
END

             'Big-Dummy/lib/Big/Dummy.pm'     => clean(<<'END'),
##package Big::Dummy;
##
##$VERSION = 0.01;
##
##=head1 NAME
##
##Big::Dummy - Try "our" hot dog's
##
##=cut
##
##1;
END

             'Big-Dummy/lib/Big/Dummy.SKIP'     => clean(<<'END'),
##Skip me please!
END

             'Big-Dummy/t/compile.t'          => clean(<<'END'),
##print "1..2\n";
##
##print eval "use Big::Dummy; 1;" ? "ok 1\n" : "not ok 1\n";
##print "ok 2 - TEST_VERBOSE\n";
END

             'Big-Dummy/Liar/Makefile.PL'     => clean(<<'END'),
##use ExtUtils::MakeMaker;
##
##my $mm = WriteMakefile(
##              NAME => 'Big::Liar',
##              VERSION_FROM => 'lib/Big/Liar.pm',
##              _KEEP_AFTER_FLUSH => 1
##             );
##
##print "Big::Liar's vars\n";
##foreach my $key (qw(INST_LIB INST_ARCHLIB)) {
##    print "$key = $mm->{$key}\n";
##}
END

             'Big-Dummy/Liar/lib/Big/Liar.pm' => clean(<<'END'),
##package Big::Liar;
##
##$VERSION = 0.01;
##
##1;
END

             'Big-Dummy/Liar/t/sanity.t'      => clean(<<'END'),
##print "1..3\n";
##
##print eval "use Big::Dummy; 1;" ? "ok 1\n" : "not ok 1\n";
##print eval "use Big::Liar; 1;" ? "ok 2\n" : "not ok 2\n";
##print "ok 3 - TEST_VERBOSE\n";
END
            );


sub setup_recurs {
    setup_mm_test_root();
    chdir 'MM_TEST_ROOT:[t]' if $Is_VMS;

    while(my($file, $text) = each %Files) {
        # Convert to a relative, native file path.
        $file = File::Spec->catfile(File::Spec->curdir, split m{\/}, $file);

        my $dir = dirname($file);
        mkpath $dir;
        open(FILE, ">$file") || die "Can't create $file: $!";
        print FILE $text;
        close FILE;
    }

    return 1;
}

sub teardown_recurs {
    foreach my $file (keys %Files) {
        my $dir = dirname($file);
        if( -e $dir ) {
            rmtree($dir) || return;
        }
    }
    return 1;
}


1;
