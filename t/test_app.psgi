package App::plackbench::test_app;

use strict;
use warnings;

use HTTP::Response;

sub ok {
    return HTTP::Response->new(200, 'OK', [], 'ok');
}

sub slow {
    my $req = shift;
    sleep 1;
    return HTTP::Response->new(200, 'OK', [], 'slow');
}

my $app = sub {
    my $request = shift;

    my $method = $request->{PATH_INFO};
    $method =~ s#^/|/$##g;
    $method =~ s#/#_#g;

    my $response = HTTP::Response->new(404, 'Not Found', [], 'Not Found');
    if (my $sub = __PACKAGE__->can($method)) {
        $response = $sub->($request);
    }

    my @headers = map { $_ => $response->header($_) } $response->header_field_names();

    my $return = [$response->code(), \@headers, [ $response->decoded_content() ]];
    return $return;
};

# Make sure this is the last statement in the file:
$app;

# vi: set ft=perl :
