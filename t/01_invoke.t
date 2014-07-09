use strict;
use warnings;

use Test::More;

use FindBin qw( $Bin );
my $script = "$Bin/../bin/plackbench";

my $output;

$output = `$script`;
like($output, qr/Usage/, 'should output a usage message with no args');
ok($?, 'should exit unsuccessfully when passed no args');

$output = `$script -n 10 $Bin/test_app.psgi /ok`;
ok(!$?, 'should exit successfully');
like($output, qr/Request times/, 'should output something reasonable');

done_testing();
