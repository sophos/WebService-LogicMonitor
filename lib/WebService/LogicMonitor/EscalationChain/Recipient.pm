package WebService::LogicMonitor::EscalationChain::Recipient;

# ABSTRACT: An escalation destination

use v5.16.3;
use Moo;

sub BUILDARGS {
    my ($class, $args) = @_;

    if (exists $args->{comment} && !$args->{comment}) {
        delete $args->{comment};
    }

    return $args;
}

has addr    => (is => 'ro');    # str
has method  => (is => 'ro');    # enum sms|email|smsemail|voice
has comment => (is => 'rw');    # array of str - emails?
has type    => (is => 'rw');    # enum? admin|arbitrary

sub TO_JSON {
    my $self = shift;

    my %hash = %{$self};

    return \%hash;
}

1;
