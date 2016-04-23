#!/usr/bin/perl
# file: imap_purge.pl
# Purge an IMAP mailbox of messages older than n days.
# Copyright (C) 2007, Chatham Township Data Corporation.  All Rights Reserved.
# Copyright (C) 2012-2016, After6 Services LLC.  All Rights Reserved.

use strict;
use Net::IMAP::Simple;
use Mail::Header;
use Term::Prompt;
use Date::Calc qw(Delta_Days);
use Date::Manip qw(ParseDate UnixDate);

my ($user,$host)	= split(/\@/,shift,2);
my $mailbox			= shift || 'INBOX';
my $passwd			= shift || 'password';
my $days			= shift || 30;
($user && $host && $mailbox && $passwd && $days) or die "Usage: imap_purge.pl username\@mailbox.host mailbox password days\n";

if ($host !~ /srvb.*?\.after6services\.com/) {
	$user .= "+" . $host;	# Adjustment for cPanel mail account naming convention.
}

$/ = "\015\012";
my $imap = Net::IMAP::Simple->new($host,Timeout=>30) or die "Can't connect to $host: $!\n";
defined($imap->login($user=>$passwd))				or die "Can't log in\n";
defined(my $messages = $imap->select($mailbox))		or die "invalid mailbox\n";
my $last	= $imap->last;

print "$mailbox has $messages messages (",$messages-$last," new)\n";

for my $msgnum (1..$messages) {
  my $header         = $imap->top($msgnum);
  my $parsedhead     = Mail::Header->new($header);
  chomp (my $subject	= $parsedhead->get('Subject'));
  chomp (my $from		= $parsedhead->get('From'));
  chomp (my $date		= $parsedhead->get('Date'));
  $from = clean_from($from);
  my $message_date = ParseDate($date);
  my ($my, $mm, $md) = UnixDate($message_date, "%Y", "%m", "%d");
  my ($cd, $cm, $cy) = (localtime)[3,4,5];
  $cy += 1900;
  $cm += 1;
  $my ||= 0;
  $mm ||= 0;
  $md ||= 0;
  
  my ($day_diff);
  
  if (($my == 0) && ($mm == 0) && ($md == 0)) {
	my $flag = $imap->delete($msgnum);
	$day_diff = -1;
  } else {
	$day_diff = Delta_Days($my, $mm, $md,
							$cy, $cm, $cd);  
	my $flag = $imap->delete($msgnum)   if ($day_diff >= int($days));
  }
  
  my $read = $imap->seen($msgnum) ? 'read' : 'unread';
  printf "%4d %-25s %-20s %-40s %-10s %4d\n",$msgnum,$from,$date,$subject,$read,$day_diff;
}
$imap->quit;

sub clean_from {
  local $_ = shift;
  /^"([^\"]+)" <\S+>/ && return $1;
  /^([^<>]+) <\S+>/   && return $1;
  /^\S+ \(([^\)]+)\)/ && return $1;
  return $_;
}
