use strict;
use warnings;

use Test::More;

use FindBin qw( $Bin );
my $script = "$^X $Bin/../bin/plackbench";

my $output;

$output = `$script`;
like($output, qr/Usage/, 'should output a usage message with no args');
ok($?, 'should exit unsuccessfully when passed no args');

$output = `$script -n 10 $Bin/test_app.psgi /ok`;
ok(!$?, 'should exit successfully');
like($output, qr/Request times/, 'should output something reasonable');

$output = `$script -e'\$_->url("/fail")' $Bin/test_app.psgi /ok`;
ok($?, 'should use -e flag as a fixup');

$output = `$script -f $Bin/fail_redirect $Bin/test_app.psgi /ok`;
ok($?, 'should use -f flag as a fixup file path');

done_testing();
