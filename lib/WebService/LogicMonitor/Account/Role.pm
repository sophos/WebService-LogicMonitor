package WebService::LogicMonitor::Account::Role;

# ABSTRACT: An account role

use v5.16.3;
use Moo;

has id          => (is => 'ro');
has description => (is => 'ro');
has name        => (is => 'ro');
has privileges  => (is => 'ro');

sub TO_JSON {
    my $self = shift;

    my %hash = %{$self};

    return \%hash;
}

1;
