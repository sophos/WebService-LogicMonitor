package WebService::LogicMonitor::Object;

use Moo::Role;

has _lm => (
    is       => 'ro',
    weak_ref => 1,
    default  => sub {

        # this is really a singleton
        WebService::LogicMonitor->new;
    },
);

sub _transform_incoming_keys {
    my ($transform, $args) = @_;

    for my $key (keys %$transform) {
        $args->{$transform->{$key}} = delete $args->{$key}
          if exists $args->{$key};
    }

    return;
}

sub _clean_empty_keys {

    my ($keys, $args) = @_;

    for my $k (@$keys) {
        if (exists $args->{$k} && !$args->{$k}) {
            delete $args->{$k};
        }
    }

    return;
}

1;
