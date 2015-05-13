#!/usr/bin/env perl

use v5.18;
use strictures;
use WebService::LogicMonitor;
use Try::Tiny;

use Data::Printer;

if ($ENV{LOGICMONITOR_DEBUG}) {
    require Log::Any::Adapter;
    Log::Any::Adapter->set('Stderr');
}

my $lm = WebService::LogicMonitor->new(
    lm_username => $ENV{LOGICMONITOR_USER},
    lm_password => $ENV{LOGICMONITOR_PASS},
    lm_company  => $ENV{LOGICMONITOR_COMPANY},
);

# TODO add an exclusion list - hosts we expect datasource to be missing from
my $datasource   = 'NTP';
my $host_groups  = $lm->get_host_groups('CA');
my $top_level_hg = shift @$host_groups;

p $top_level_hg;

$host_groups = $lm->get_host_group_children($top_level_hg->{id});

my %groups_to_enable;
my @hosts_missing_datasource;
foreach my $hg (@$host_groups) {
    p $hg;
    say "Checking group: $hg->{name}";
    my $hosts = $lm->get_hosts($hg->{id});

    # p $hosts;
    foreach my $host (@$hosts) {
        say '-' x 25;
        say "Checking host: $host->{hostName}";
        my $instances;
        try {
            $instances =
              $lm->get_data_source_instances($host->{id}, $datasource);
        }
        catch {
            say $_;
            push @hosts_missing_datasource, $host->{hostName};
        };

        next unless $instances;

        # p $instances;

        # NTP has only one instance
        my $instance = shift @$instances;

        print 'datasource status: ';
        if ($instance->{enabled}) {
            say 'enabled';
        } else {
            say 'disabled';
        }

        print 'alert status: ';
        if ($instance->{alertEnable}) {
            say 'enabled';
        } else {
            say 'disabled';
        }

        print 'group disabled: ';
        if ($instance->{disabledAtGroup}) {
            say 'yes - ' . $instance->{disabledAtGroup};
            $groups_to_enable{$instance->{disabledAtGroup}} = 1;
        } else {
            say 'no';
        }
    }
}

p %groups_to_enable;
p @hosts_missing_datasource;
