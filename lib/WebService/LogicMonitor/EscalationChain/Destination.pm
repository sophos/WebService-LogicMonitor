package WebService::LogicMonitor::EscalationChain::Destination;

# ABSTRACT: An escalation destination

use v5.16.3;
use Moo;

has type   => (is => 'rw');    # enum simple|timebased
has stages => (is => 'rw');    # arrayref

sub TO_JSON {
    my $self = shift;

    my @stages;

    #$self->stages
    return [{
            type   => $self->type,
            stages => $self->stages,
        }];
}

1;
