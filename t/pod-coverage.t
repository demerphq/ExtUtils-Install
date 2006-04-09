#!perl -T

BEGIN {
    if( $ENV{PERL_CORE} ) {
        @INC = ('../../lib', '../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}
chdir 't';

use Test::More;
eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;
plan tests => 3;
pod_coverage_ok( "ExtUtils::Install");
pod_coverage_ok( "ExtUtils::Installed");
pod_coverage_ok( "ExtUtils::Packlist");