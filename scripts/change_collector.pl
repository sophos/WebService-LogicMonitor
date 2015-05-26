#!/usr/bin/env perl

use v5.18;
use strictures;
use autodie;
use Carp;
use Getopt::Long qw/:config no_ignore_case bundling/;
use Path::Tiny;
use Try::Tiny;
use Data::Printer;

use WebService::LogicMonitor;

my $opt = {};

my $lm = WebService::LogicMonitor->new(
    username => $ENV{LOGICMONITOR_USER},
    password => $ENV{LOGICMONITOR_PASS},
    company  => $ENV{LOGICMONITOR_COMPANY},
);

sub get_options {

    my $getopt = GetOptions $opt,
      'debug|d!', 'group|g=s', 'old_agent_id=i', 'new_agent_id=i'
      or croak "Commandline error\n";

    if ($ENV{LOGICMONITOR_DEBUG} || $opt->{debug}) {
        require Log::Any::Adapter;
        Log::Any::Adapter->set('Stderr');
    }

    return;
}

sub update_host {
    my $host     = shift;
    my $new_host = $lm->update_host(
        $host->{id},
        opType        => 'replace',
        name          => $host->{name},
        hostName      => $host->{hostName},
        displayedAs   => $host->{displayedAs},
        agentId       => $opt->{new_agent_id},
        fullPathInIds => $host->{fullPathInIds},
        description   => $host->{description},
        alertEnable   => $host->{alertEnable},
        link          => $host->{link},
    );

    $new_host = $lm->get_host($host->{displayedAs});
    p $new_host;

}

get_options;

my $host_groups =
  $lm->get_host_groups(fullPath => 'Cloud/us-west-2/Sophos-Cloud-PROD');
my $host_group = shift @$host_groups;

p $host_group;

my $hosts = $lm->get_hosts($host_group->{id});

#p $hosts;

foreach my $host (@$hosts) {
    if ($host->{agentId} == $opt->{old_agent_id}) {
        say "$host->{name} uses old collector";
        p $host;
        update_host($host);

        #	exit;
    } elsif ($host->{agentId} == $opt->{new_agent_id}) {
        say "$host->{name} already uses new collector";
    } else {
        say "$host->{name} uses collector $host->{agentId}";
    }
}
