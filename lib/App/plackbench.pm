package App::plackbench;

use strict;
use warnings;
use autodie;
use v5.10;

use HTTP::Request qw();
use List::Util qw( reduce );
use Plack::Test qw( test_psgi );
use Plack::Util qw();
use Scalar::Util qw( reftype );
use Time::HiRes qw( gettimeofday tv_interval );

use App::plackbench::Stats;

my %attributes = (
    app       => \&_build_app,
    count     => 1,
    warm      => 0,
    fixup     => sub { [] },
    post_data => undef,
    psgi_path => undef,
    uri       => undef,
);
for my $attribute (keys %attributes) {
    my $accessor = sub {
        my $self = shift;

        # $self is a coderef, so yes.. call $self on $self.
        return $self->$self($attribute, @_);
    };

    no strict 'refs';
    *$attribute = $accessor;
}

sub new {
    my $class = shift;
    my %stash = @_;

    # $self is a blessed coderef, which is a closure on %stash. I might end up
    # replacing this with a more typical blessed hashref. But, I don't think
    # it's as awful as it sounds.

    my $self = sub {
        my $self = shift;
        my $key = shift;

        $stash{$key} = shift if @_;

        if (!exists $stash{$key}) {
            my $value = $attributes{$key};

            # If the default value is a subref, call it.
            if (ref($value) && ref($value) eq 'CODE') {
                $value = $self->$value();
            }

            $stash{$key} = $value;
        }

        return $stash{$key};
    };

    return bless $self, $class;
}

sub _build_app {
    my $self = shift;
    return Plack::Util::load_psgi($self->psgi_path());
}

sub run {
    my $self = shift;
    my %args = @_;

    my $app   = $self->app();
    my $count = $self->count();

    my $requests = $self->_create_requests();

    if ( $self->warm() ) {
        $self->_execute_request( $requests->[0] );
    }

    # If it's possible to enable NYTProf, then do so now.
    if ( DB->can('enable_profile') ) {
        DB::enable_profile();
    }

    my $stats = reduce {
        my $request_number = $b % scalar(@{$requests});
        my $request = $requests->[$request_number];

        my $elapsed = $self->_time_request( $request );
        $a->insert($elapsed);
        $a;
    }  App::plackbench::Stats->new(), ( 0 .. ( $count - 1 ) );

    return $stats;
}

sub _time_request {
    my $self = shift;

    my @start = gettimeofday;
    $self->_execute_request(@_);
    return tv_interval( \@start );
}

sub _create_requests {
    my $self = shift;

    my @requests;
    if ( $self->post_data() ) {
        @requests = map {
            my $req = HTTP::Request->new( POST => $self->uri() );
            $req->content($_);
            $req;
        } @{ $self->post_data() };
    }
    else {
        @requests = ( HTTP::Request->new( GET => $self->uri() ) );
    }

    $self->_fixup_requests(\@requests);

    return \@requests;
}

sub _fixup_requests {
    my $self = shift;
    my $requests = shift;

    my $fixups = $self->fixup();
    $fixups = [ grep { reftype($_) && reftype($_) eq 'CODE' } @{$fixups} ];

    for my $request (@{$requests}) {
        $_->($request) for @{$fixups};
    }

    return;
}

sub add_fixup_from_file {
    my $self = shift;
    my $file = shift;

    my $sub = do $file;

    if (!$sub) {
        die($@ || $!);
    }

    if (!reftype($sub) || !reftype($sub) eq 'CODE') {
        die("$file: does not return a subroutine reference");
    }

    my $existing = $self->fixup();
    if (!$existing || !reftype($existing) || reftype($existing) ne 'ARRAY') {
        $self->fixup([]);
    }

    push @{$self->fixup()}, $sub;

    return;
}

sub _execute_request {
    my $self = shift;
    my $request = shift;

    test_psgi $self->app(), sub {
        my $cb       = shift;
        my $response = $cb->($request);
        if ( $response->is_error() ) {
            die "Request failed: " . $response->decoded_content;
        }
    };

    return;
}

1;

__END__

=head1 NAME

App::plackbench

=head2 SEE ALSO

L<plackbench>
