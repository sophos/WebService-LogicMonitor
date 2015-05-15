use v5.10.1;
use Test::Roo;
use Test::Fatal;
use DateTime;
use lib 't/lib';

with 'LogicMonitorTests';

has host       => (is => 'ro', default => 'test1');
has dsi        => (is => 'ro', default => 'Ping');
has datapoint  => (is => 'ro', default => 'PingLossPercent');
has datapoint2 => (is => 'ro', default => 'sentpkts');

# valid datapoints for NetSNMPMem
has expected_datapoints => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        [sort qw/average maxrtt minrtt PingLossPercent recvdpkts sentpkts/];
    },
);

test 'get data now' => sub {
    my $self = shift;

    like(
        exception { $self->lm->get_data },
        qr/'host' is required/,
        'missing host',
    );

    like(
        exception { $self->lm->get_data(host => $self->host) },
        qr/'dsi' is required/,
        'missing datasource instance',
    );

    my $data;
    is(
        exception {
            $data =
              $self->lm->get_data(host => $self->host, dsi => $self->dsi);
        },
        undef,
        'got some data',
    );

    isa_ok $data, 'ARRAY';
    is scalar @$data, 1, 'One value in array';
    is_deeply [sort keys %{$data->[0]->{values}}],
      \@{$self->expected_datapoints}, 'Got all expected keys';
};

test 'get data one month' => sub {
    my $self = shift;

    my $cur_dt = DateTime->now;

    # I am assuming there will always be enough data for the previous month
    my $last_month_start_dt =
      $cur_dt->clone->set_day(1)->subtract(months => 1)->subtract(days => 1)
      ->set_minute(0)->set_hour(0)->set_second(0)->add(days => 1);

    my $last_month_end_dt =
      $cur_dt->clone->set_day(1)->add(months => 1)->subtract(days => 1)
      ->set_minute(0)->set_hour(0)->set_second(0)->subtract(months => 1);

    diag
      "Getting records for one month: $last_month_start_dt - $last_month_end_dt";

    my $data;
    is(
        exception {
            $data = $self->lm->get_data(
                host  => $self->host,
                dsi   => $self->dsi,
                start => $last_month_start_dt->epoch,
                end   => $last_month_end_dt->epoch,
            );
        },
        undef,
        'got some data',
    );

    isa_ok $data, 'ARRAY';

    # XXX data contains one entry per 12h40m
    ok scalar @$data <= 61 && scalar @$data >= 59, '59 - 61 values in array';

    is_deeply [sort keys %{$data->[0]->{values}}],
      \@{$self->expected_datapoints}, 'Got all expected keys';
};

test 'get data by period' => sub {
    my $self = shift;

    my $data;
    is(
        exception {
            $data = $self->lm->get_data(
                host   => $self->host,
                dsi    => $self->dsi,
                period => '1days',
            );
        },
        undef,
        'got 1 day of data',
    );
    isa_ok $data, 'ARRAY';

    # is scalar @$data, 182, '182 values in array';
    is_deeply [sort keys %{$data->[0]->{values}}],
      \@{$self->expected_datapoints}, 'Got all expected keys';

    is(
        exception {
            $data = $self->lm->get_data(
                host   => $self->host,
                dsi    => $self->dsi,
                period => '4hours',
            );
        },
        undef,
        'got 4 hours of data',
    );

    isa_ok $data, 'ARRAY';

};

test 'get only one datapoint' => sub {
    my $self = shift;

    like(
        exception {
            $self->lm->get_data(
                host      => $self->host,
                dsi       => $self->dsi,
                datapoint => $self->datapoint,
            );
        },
        qr/'datapoint' must be an arrayref/,
        'Bad args',
    );

    my $data;
    is(
        exception {
            $data = $self->lm->get_data(
                host      => $self->host,
                dsi       => $self->dsi,
                datapoint => [$self->datapoint],
            );
        },
        undef,
        'got some data',
    );

    is scalar @$data, 1, '1 value in array';

    is keys %{$data->[0]->{values}}, 1, 'Got one keys...';
    ok exists $data->[0]->{values}->{$self->datapoint}, '... and it matches';
};

test 'get two datapoints' => sub {
    my $self = shift;

    my $data;
    is(
        exception {
            $data = $self->lm->get_data(
                host      => $self->host,
                dsi       => $self->dsi,
                datapoint => [$self->datapoint, $self->datapoint2],
            );
        },
        undef,
        'got some data',
    );

    isa_ok $data, 'ARRAY';
    is scalar @$data, 1, '1 value in array';

    is keys %{$data->[0]->{values}}, 2, 'Got two keys...';
    ok exists $data->[0]->{values}->{$self->datapoint},  '... one matches';
    ok exists $data->[0]->{values}->{$self->datapoint2}, '... two matches';
};

test 'get aggregated datapoint' => sub {
    my $self = shift;

    my ($data, $min, $avg, $max);
    is(
        exception {
            $data = $self->lm->get_data(
                host      => $self->host,
                dsi       => $self->dsi,
                datapoint => [$self->datapoint],
                aggregate => 'AVERAGE',
                period    => '1weeks'
              )
        },
        undef,
        'got 1 week average',
    );
    isa_ok $data, 'ARRAY';
    $avg = $data->[0]->{values}->{$self->datapoint};

    is exception {
        $data = $self->lm->get_data(
            host      => $self->host,
            dsi       => $self->dsi,
            datapoint => [$self->datapoint],
            aggregate => 'MAX',
            period    => '1weeks'
          )
    }, undef, 'got 1 week max';
    isa_ok $data, 'ARRAY';
    $max = $data->[0]->{values}->{$self->datapoint};

    is exception {
        $data = $self->lm->get_data(
            host      => $self->host,
            dsi       => $self->dsi,
            datapoint => [$self->datapoint],
            aggregate => 'MIN',
            period    => '1weeks'
          )
    }, undef, 'got 1 week min';
    isa_ok $data, 'ARRAY';
    $min = $data->[0]->{values}->{$self->datapoint};

    #   cmp_ok $min, '<', $avg, 'Numbers seem sane...';
    #   cmp_ok $avg, '<', $max, 'Numbers seem sane...';
};

run_me;
done_testing;
