use strict;
use warnings;

use Test::More;
use Test::Deep;

use FindBin qw( $Bin );
my $psgi_path = "$Bin/test_app.psgi";

use App::plackbench;

subtest 'attribute' => \&test_attributes;
subtest 'run' => \&test_run;
subtest 'fixup' => \&test_fixup;
done_testing();

sub test_attributes {
    my $bench = App::plackbench->new(psgi_path => $psgi_path);

    ok(!$bench->warm(), 'warm() should default to false');

    $bench->warm(1);
    ok($bench->warm(), 'warm() should be setable');

    ok(App::plackbench->new(warm => 1)->warm(), 'warm() should be setable in the constructor');

    ok($bench->app(), 'lazy-built attributes should work');

    return;
}

sub test_run {
    my $bench = App::plackbench->new(
        psgi_path => $psgi_path,
        count     => 5,
        uri       => '/ok',
    );
    my $stats = $bench->run();
    ok($stats->isa('App::plackbench::Stats'), 'run() should return App::plackbench::Stats object');

    is($stats->count(), $bench->count(), 'the stats object should have the correct number of times');

    cmp_ok($stats->mean(), '<', 1, 'the returned times should be within reason');

    return;
}

sub test_fixup {
    my $counter = 0;

    my $bench = App::plackbench->new(
        psgi_path => $psgi_path,
        count     => 5,
        uri       => '/ok',
        fixup     => [
            sub {
                $counter++;
                shift->header(FooBar => '1.0');
            }
        ],
    );

    $bench->run();
    is($counter, 1, 'fixup subs should be called once per unique request');
    is($bench->app->_get_last_request()->{HTTP_FOOBAR}, '1.0', 'changes made to the request should be kept');

    $bench->fixup(sub { $counter++ });
    $bench->run();
    is($counter, 2, 'non-arrayref single fixup sub should be called, too');

    $bench->fixup('asdf');
    eval {
        $bench->run();
    };
    ok(!$@, 'should ignore non-coderefs in fixup()');

    return;
}
