#
# Copyright (C) 2010 JBA Network (http://www.jbanetwork.com)
# WWW::MyNewsletterBuilder is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# WWW::MyNewsletterBuilder is an interface to the mynewsletterbuilder.com
# XML-RPC API.
#
# $Id: MyNewsletterBuilder.pm 59133 2010-04-20 04:11:37Z bo $
#

package WWW::MyNewsletterBuilder;

use strict;
use warnings;
use Frontier::Client;

require Exporter;

our @ISA = qw(Exporter);

our $VERSION = '0.01b01';

sub new {
	my $class = shift;
	my $args  = ($#_ == 0) ? { %{ (shift) } } : { @_ };

	if (!$args->{api_key}){
		die('you must pass an api_key to WWW::MyNewsletterBuilder->new()');
	}

	my $self  = {
		api_key       => $args->{api_key},
		username      => $args->{username},
		password      => $args->{password},
		timeout       => $args->{timeout}       || 300,
		secure        => $args->{secure}        || 0,
		no_validation => $args->{no_validation} || 0,
		api_host      => $args->{api_host}      || 'api.mynewsletterbuilder.com',
		api_version   => $args->{api_version}   || '1.0',
		debug         => $args->{debug}         || 0,
	};

	bless($self, $class);

	my $url = $self->buildUrl();
	if ($self->{debug}){
		print "url: $url\n";
	}
	
	$self->{client} = $self->getClient($url);
	return $self;
}

sub Timeout{
	my $self = shift;
	$self->{timeout} = shift;
	$self->{client}->{ua}->timeout($self->{timeout});
	return 1;
}

sub Campaigns{
	my $self    = shift;
	my $filters = ($#_ == 0) ? { %{ (shift) } } : { @_ };
	# make sure that if filters is populated
	# it is a hashref
	if (	$filters && 
	     	ref($filters) ne 'HASH'
	){
		$self->error('filter passed to WWW::MyNewsletterBuilder->Campaings() does not appear to be valid', 1);
	}
	
	return $self->Execute('Campaigns', $filters);
}

sub CampaignDetails{
	my $self = shift;
	my $id   = shift;

	$self->error('invalid id passed to WWW::MyNewsletterBuilder->CampaingDetails()') unless ($id =~ /^\d+$/);

	return $self->Execute('CampaignDetails', $id);
}

sub CampaignCreate{
	my $self          = shift;
	my $name          = shift;
	my $subject       = shift;
	my $from          = shift;
	my $reply         = shift;
	my $html          = shift;
	my $text          = shift || '';
	my $link_tracking = shift || 1;
	my $gat           = shift || 0;
	
	$self->error('invalid name passed to WWW::MyNewsletterBuilder->CampaignCreate()')               unless ($name           =~ /^.+$/);
	$self->error('invalid subject passed to WWW::MyNewsletterBuilder->CampaignCreate()')            unless ($subject        =~ /^.+$/);
	$self->error('invalid html passed to WWW::MyNewsletterBuilder->CampaignCreate()')               unless ($html           =~ /^.+$/);
	$self->error('invalid text passed to WWW::MyNewsletterBuilder->CampaignCreate()')               unless (!$text || $text =~ /^.+$/);
	$self->error('invalid link_tracking flag passed to WWW::MyNewsletterBuilder->CampaignCreate()') unless ($link_tracking  =~ /^(0|1)$/);
	$self->error('invalid gat flag passed to WWW::MyNewsletterBuilder->CampaignCreate()')           unless ($gat            =~ /^(0|1)$/);
	#should probably add some from/reply validation here
	
	return $self->Execute(
		'CampaignCreate',
		$name,
		$subject,
		$from,
		$reply,
		$html,
		$text,
		$link_tracking,
		$gat,
	);
}

sub CampaignUpdate{
	my $self          = shift;
	my $id            = shift;
	my $details       = shift;
	
	
	$self->error('invalid id passed to WWW::MyNewsletterBuilder->CampaignCreate()') unless ($id =~ /^\d+$/);
	#TODO: should probably add some detail validation here
	
	return $self->Execute(
		'CampaignUpdate',
		$id,
		$details,
	);
}

sub CampaignCopy{
	my $self = shift;
	my $id   = shift;
	my $name = shift || '';

	$self->error('invalid id passed to WWW::MyNewsletterBuilder->CampaingStats()') unless ($id =~ /^\d+$/);

	return $self->Execute('CampaignCopy', $id, $name);
}

sub CampaignDelete{
	my $self = shift;
	my $id   = shift;

	$self->error('invalid id passed to WWW::MyNewsletterBuilder->CampaingStats()') unless ($id =~ /^\d+$/);

	return $self->Execute('CampaignDelete', $id);
}

sub CampaignSchedule{
	my $self      = shift;
	my $id        = shift;
	my $when      = shift;
	my $lists     = shift;
	my $smart     = shift || 0;
	my $confirmed = shift || 0;

	$self->error('invalid id passed to WWW::MyNewsletterBuilder->CampaingStats()')              unless ($id        =~ /^\d+$/);
	$self->error('invalid when passed to WWW::MyNewsletterBuilder->CampaignCreate()')           unless ($when      =~ /^.+$/);
	$self->error('invalid smart flag passed to WWW::MyNewsletterBuilder->CampaignCreate()')     unless ($smart     =~ /^(0|1)$/);
	$self->error('invalid confirmed flag passed to WWW::MyNewsletterBuilder->CampaignCreate()') unless ($confirmed =~ /^(0|1)$/);
	#TODO: add some validation for $lists here

	return $self->Execute('CampaignSchedule', $id, $when, $lists, $smart, $confirmed);
}

sub CampaignStats{
	my $self = shift;
	my $id   = shift;

	$self->error('invalid id passed to WWW::MyNewsletterBuilder->CampaingStats()') unless ($id =~ /^\d+$/);

	return $self->Execute('CampaignStats', $id);
}

sub CampaignRecipients{
	my $self  = shift;
	my $id    = shift;
	my $page  = shift || 0;
	my $limit = shift || 1000;

	$self->error('invalid id passed to WWW::MyNewsletterBuilder->CampaingRecipients()')    unless ($id    =~ /^\d+$/);
	$self->error('invalid page passed to WWW::MyNewsletterBuilder->CampaingRecipients()')  unless ($page  =~ /^\d+$/);
	$self->error('invalid limit passed to WWW::MyNewsletterBuilder->CampaingRecipients()') unless ($limit =~ /^\d+$/);

	return $self->Execute(
		'CampaignRecipients',
		$id,
		$page,
		$limit
	);
}

sub CampaignOpens{
	my $self  = shift;
	my $id    = shift;
	my $page  = shift || 0;
	my $limit = shift || 1000;

	$self->error('invalid id passed to WWW::MyNewsletterBuilder->CampaignOpens()')    unless ($id    =~ /^\d+$/);
	$self->error('invalid page passed to WWW::MyNewsletterBuilder->CampaignOpens()')  unless ($page  =~ /^\d+$/);
	$self->error('invalid limit passed to WWW::MyNewsletterBuilder->CampaignOpens()') unless ($limit =~ /^\d+$/);

	return $self->Execute(
		'CampaignOpens',
		$id,
		$page,
		$limit
	);
}

sub CampaignBounces{
	my $self  = shift;
	my $id    = shift;
	my $page  = shift || 0;
	my $limit = shift || 1000;

	$self->error('invalid id passed to WWW::MyNewsletterBuilder->CampaignBounces()')    unless ($id    =~ /^\d+$/);
	$self->error('invalid page passed to WWW::MyNewsletterBuilder->CampaignBounces()')  unless ($page  =~ /^\d+$/);
	$self->error('invalid limit passed to WWW::MyNewsletterBuilder->CampaignBounces()') unless ($limit =~ /^\d+$/);

	return $self->Execute(
		'CampaignBounces',
		$id,
		$page,
		$limit
	);
}

sub CampaignClicks{
	my $self   = shift;
	my $id     = shift;
	my $page   = shift || 0;
	my $limit  = shift || 1000;

	$self->error('invalid id passed to WWW::MyNewsletterBuilder->CampaignClicks()')     unless ($id     =~ /^\d+$/);
	$self->error('invalid page passed to WWW::MyNewsletterBuilder->CampaignClicks()')   unless ($page   =~ /^\d+$/);
	$self->error('invalid limit passed to WWW::MyNewsletterBuilder->CampaignClicks()')  unless ($limit  =~ /^\d+$/);

	return $self->Execute(
		'CampaignClicks',
		$id,
		$page,
		$limit
	);
}

sub CampaignClickDetails{
	my $self   = shift;
	my $id     = shift;
	my $url_id = shift;
	my $page   = shift || 0;
	my $limit  = shift || 1000;

	$self->error('invalid id passed to WWW::MyNewsletterBuilder->CampaignClickDetails()')     unless ($id     =~ /^\d+$/);
	$self->error('invalid url_id passed to WWW::MyNewsletterBuilder->CampaignClickDetails()') unless ($url_id =~ /^\d+$/);
	$self->error('invalid page passed to WWW::MyNewsletterBuilder->CampaignClickDetails()')   unless ($page   =~ /^\d+$/);
	$self->error('invalid limit passed to WWW::MyNewsletterBuilder->CampaignClickDetails()')  unless ($limit  =~ /^\d+$/);

	return $self->Execute(
		'CampaignClickDetails',
		$id,
		$url_id,
		$page,
		$limit
	);
}

sub CampaignSubscribes{
    my $self  = shift;
	my $id    = shift;
	my $page  = shift || 0;
	my $limit = shift || 1000;

	$self->error('invalid id passed to WWW::MyNewsletterBuilder->CampaignSubscribes()')    unless ($id    =~ /^\d+$/);
	$self->error('invalid page passed to WWW::MyNewsletterBuilder->CampaignSubscribes()')  unless ($page  =~ /^\d+$/);
	$self->error('invalid limit passed to WWW::MyNewsletterBuilder->CampaignSubscribes()') unless ($limit =~ /^\d+$/);

	return $self->Execute(
		'CampaignSubscribes',
		$id,
		$page,
		$limit
	);
}

sub CampaignUnsubscribes{
    my $self  = shift;
	my $id    = shift;
	my $page  = shift || 0;
	my $limit = shift || 1000;

	$self->error('invalid id passed to WWW::MyNewsletterBuilder->CampaignUnsubscribes()')    unless ($id    =~ /^\d+$/);
	$self->error('invalid page passed to WWW::MyNewsletterBuilder->CampaignUnsubscribes()')  unless ($page  =~ /^\d+$/);
	$self->error('invalid limit passed to WWW::MyNewsletterBuilder->CampaignUnsubscribes()') unless ($limit =~ /^\d+$/);

	return $self->Execute(
		'CampaignUnsubscribes',
		$id,
		$page,
		$limit
	);
}

sub CampaignUrls{
    my $self  = shift;
	my $id    = shift;

	$self->error('invalid id passed to WWW::MyNewsletterBuilder->CampaignUrls()') unless ($id  =~ /^\d+$/);

	return $self->Execute('CampaignUrls', $id);
}

sub Lists{
	my $self = shift;
	
	return $self->Execute('Lists');
}

sub ListDetails{
	my $self = shift;
	my $id   = shift;
	
	$self->error('invalid id passed to WWW::MyNewsletterBuilder->ListDetails()') unless ($id  =~ /^\d+$/);
	
	return $self->Execute('ListDetails', $id);
}

sub ListCreate{
	my $self        = shift;
	my $name        = shift;
	my $description = shift || '';
	my $visible     = shift || 0;
	my $default     = shift || 0;

	$self->error('invalid name passed to WWW::MyNewsletterBuilder->ListCreate()')         unless ($name        =~ /^.+$/);
	$self->error('invalid description passed to WWW::MyNewsletterBuilder->ListCreate()')  unless ($description =~ /^.+$/);
	$self->error('invalid visible flag passed to WWW::MyNewsletterBuilder->ListCreate()') unless ($visible     =~ /^(0|1)$/);
	$self->error('invalid default flag passed to WWW::MyNewsletterBuilder->ListCreate()') unless ($default     =~ /^(0|1)$/);

	return $self->Execute(
		'ListCreate',
		$name,
		$description,
		$visible,
		$default
	);
}

sub ListUpdate{
	my $self        = shift;
	my $id          = shift;
	my $details     = shift;

	$self->error('invalid id passed to WWW::MyNewsletterBuilder->ListUpdate()')           unless ($id      =~ /^\d+$/);
	#TODO: details hashref validation

	return $self->Execute(
		'ListUpdate',
		$id,
		$details,
	);
}

sub ListDelete{
	my $self        = shift;
	my $id          = shift;
	my $delete_subs = shift;

	$self->error('invalid cat_id passed to WWW::MyNewsletterBuilder->ListDelete()')           unless ($id          =~ /^\d+$/);
	$self->error('invalid delete_subs flag passed to WWW::MyNewsletterBuilder->ListDelete()') unless ($delete_subs =~ /^(0|1)$/);

	return $self->Execute('ListDelete', $id, $delete_subs);
}

sub Subscribe{
	my $self            = shift;
	my $details         = shift;
	my $lists           = shift;
	my $skip_opt_in     = shift || 0;
	my $update_existing = shift || 1;

	$self->error('invalid skip_opt_in flag passed to WWW::MyNewsletterBuilder->Subscribe()')     unless ($skip_opt_in     =~ /^(0|1)$/);
	$self->error('invalid update_existing flag passed to WWW::MyNewsletterBuilder->Subscribe()') unless ($update_existing =~ /^(0|1)$/);
	#TODO: validate details and lists

	return $self->Execute(
		'Subscribe',
		$details,
		$lists,
		$skip_opt_in,
		$update_existing
	);
}

sub SubscribeBatch{
	my $self            = shift;
	my $subscribers     = shift;
	my $lists           = shift;
	my $skip_opt_in     = shift || 0;
	my $update_existing = shift || 1;

	$self->error('invalid skip_opt_in flag passed to WWW::MyNewsletterBuilder->SubscribeBatch()')     unless ($skip_opt_in     =~ /^(0|1)$/);
	$self->error('invalid update_existing flag passed to WWW::MyNewsletterBuilder->SubscribeBatch()') unless ($update_existing =~ /^(0|1)$/);
	#TODO: validate subscribers and lists

	return $self->Execute(
		'SubscribeBatch',
		$subscribers,
		$lists,
		$skip_opt_in,
		$update_existing
	);
}

sub SubscriberInfo{
	my $self        = shift;
	my $id_or_email = shift;

	$self->error('invalid id_or_email passed to WWW::MyNewsletterBuilder->SubscriberInfo()') unless ($id_or_email =~ /^.+$/);

	return $self->Execute('SubscriberInfo', $id_or_email);
}

sub SubscriberUpdate{
	my $self        = shift;
	my $id_or_email = shift;
	my $details     = shift;
	my $lists       = shift;
	
	$self->error('invalid id_or_email passed to WWW::MyNewsletterBuilder->SubscriberUpdate()') unless ($id_or_email =~ /^.+$/);
	#TODO: validate details and lists

	return $self->Execute(
		'SubscriberUpdate',
		$id_or_email,
		$details,
		$lists,
	);
}

sub SubscriberUnsubscribe{
	my $self = shift;
	my $id_or_email   = shift;

	$self->error('invalid id_or_email passed to WWW::MyNewsletterBuilder->SubscriberUnsubscribe()') unless ($id_or_email =~ /^.+$/);

	return $self->Execute('SubscriberUnsubscribe', $id_or_email);
}

sub SubscriberUnsubscribeBatch{
	my $self = shift;
	my $id_or_email   = shift;

	$self->error('invalid id_or_email passed to WWW::MyNewsletterBuilder->SubscriberUnsubscribeBatch()') unless ($id_or_email =~ /^.+$/);

	return $self->Execute('SubscriberUnsubscribeBatch', $id_or_email);
}

sub SubscriberDelete{
	my $self        = shift;
	my $id_or_email = shift;

	$self->error('invalid id_or_email passed to WWW::MyNewsletterBuilder->SubscriberDelete()') unless ($id_or_email =~ /^.+$/);

	return $self->Execute('SubscriberDelete', $id_or_email);
}

sub SubscriberDeleteBatch{
	my $self          = shift;
	my $ids_or_emails = shift;

	#TODO: validate $ids_or_emails

	return $self->Execute('SubscriberDeleteBatch', $ids_or_emails);
}

sub AccountKeys{
	my $self     = shift;
	my $username = shift;
	my $password = shift;
	my $disabled = shift || 0;

	$self->error('invalid username passed to WWW::MyNewsletterBuilder->AccountKeys()')      unless ($username =~ /^.+$/);
	$self->error('invalid password passed to WWW::MyNewsletterBuilder->AccountKeys()')      unless ($password =~ /^.+$/);
	$self->error('invalid disabled flag passed to WWW::MyNewsletterBuilder->AccountKeys()') unless ($disabled     =~ /^(0|1)$/);

	return $self->Execute(
		'AccountKeys',
		$username,
		$password,
		$disabled,
	);
}

sub AccountKeyAdd{
	my $self     = shift;
	my $username = shift;
	my $password = shift;

	$self->error('invalid username passed to WWW::MyNewsletterBuilder->AccountKeyAdd()') unless ($username =~ /^.+$/);
	$self->error('invalid password passed to WWW::MyNewsletterBuilder->AccountKeyAdd()') unless ($password =~ /^.+$/);

	return $self->Execute('AccountKeyAdd', $username, $password);
}

sub AccountKeyRemove{
	my $self     = shift;
	my $username = shift;
	my $password = shift;

	$self->error('invalid username passed to WWW::MyNewsletterBuilder->AccountKeyRemove()') unless ($username =~ /^.+$/);
	$self->error('invalid password passed to WWW::MyNewsletterBuilder->AccountKeyRemove()') unless ($password =~ /^.+$/);

	return $self->Execute('AccounKeyRemove', $username, $password);
}

 ##
 # Test server response
 # @param string String to echo
 # @return string
 ##
sub HelloWorld{
	my $self = shift;
	my $val  = shift;

	return $self->Execute('HelloWorld', $val);
}

 ##
 # Connect to remote server and handle response.
 # @param string $method Action to invoke
 # @param mixed $params Parameters required for $method
 # @return mixed Server response, FALSE on error.
 ##
sub Execute{
	my $self   = shift;
	my $method = shift;

	$self->{errno}  = '';
	$self->{errstr} = '';

	my $data = $self->{client}->call($method, $self->{api_key}, @_);

	if ($self->{debug}){
		use Data::Dumper;
		print 'returned data'."\n";
		print Dumper $data;
	}

	if (!$data){
		$self->{errno}  = 2;
		$self->{errstr} = 'Empty response from API server';
		return 0;
	}

	if (ref($data) eq 'HASH' && $data->{'errno'}){
		$self->{errno} = $data->{'errno'};
		$self->{errstr} = $data->{'errstr'};
		return 0;
	}

	return $data;
}

sub buildUrl{
	my $self = shift;
	my $url;
	if ($self->{secure}){
		$url = 'https://';
	}
	else{
		$url = 'http://';	
	}

	return $url . $self->{api_host} . '/' . $self->{api_version};
}

sub getClient{
	my $self = shift;
	my $url  = shift;

	my $client = Frontier::Client->new(
		url   => $url,
		debug => 0,
	);

	# we have to modify Frontier's LWP instance a little bit.
	$client->{ua}->agent('MNB_API Perl ' . $self->{api_version} . '/' . $VERSION . '-' . '$Rev: 59133 $');
	$client->{ua}->requests_redirectable(['GET', 'HEAD', 'POST' ]);
	$client->{ua}->timeout($self->{timeout});

	return $client;
}

sub error{
	my $self = shift;
	my $msg  = shift;
	my $warn = shift || 0;
	
	if ($self->{no_validation} || $warn){
		warn($msg);
	}
	else{
		die($msg);
	}
}

1;
__END__

=head1 NAME

WWW::MyNewsletterBuilder - Perl implementation of the mynewsletterbuilder.com API

=head1 SYNOPSIS

	#!/usr/bin/perl
	use warnings;
	use strict;
	use WWW::MyNewsletterBuilder;
	
	my $mnb = WWW::MyNewsletterBuilder->new(
		api_key     => , # your key here
	);
	
	print $mnb->HelloWorld('Perl Test');
	
	my $campaigns = $mnb->Campaigns( status => 'all' );
	
	my $cam_id = $mnb->CampaignCreate(
		'perl test',
		'perl test subject',
		{
			name  => 'perl test from name',
			email => 'robert@jbanetwork.com'
		},
		{
			name  => 'perl test reply name',
			email => 'robert@jbanetwork.com'
		},
		'<a href="mynewsletterbuilder.com">html content</a>',
		'text content',
	);

	my $list_id = $mnb->ListCreate(
		'perl test',
		'perl test list',
	);

	my $sub_id = $mnb->Subscribe(
		{
			email            => 'robert@jbanetwork.com',
			first_name       => 'Robert',
			last_name        => 'Davis',
			company_name     => 'JBA Network',
			phone_work       => '8282320016,',
			address_1        => '311 Montford Ave',
			city             => 'Asheville',
			state            => 'NC',
			zip              => '28801',
			country          => 'US',
			'blah blah balh' => 'perl goes blah.',
		},
		[ $list_id ]
	);

	$mnb->CampaignSchedule(
		$cam_id,
		time(),
		[ $list_id ],
	);

	$mnb->SubscriberDelete("$sub_id");
	
	$mnb->ListDelete($list_id);
	
	$mnb->CampaignDelete($cam_id);

=head1 DESCRIPTION

=head2 Methods

=over 4

=item $mnb = WWW::MyNewsletterBuilder->new( %options )

This method constructs a new C<WWW::MyNewsletterBuilder> object and returns it.
Key/value pair arguments may be provided to set up the initial state.
The following options correspond to attribute methods described below:

   KEY                     DEFAULT
   -----------             --------------------
   api_key                 undef (REQUIRED)
   username                undef
   password                undef
   timeout                 300
   secure                  0 (1 will use ssl)
   no_validation           0 (1 will warn instead of die on invalid argument)
   #############################################
   ### dev options... use at your own risk...### 
   #############################################   
   api_host                'api.mynewsletterbuilder.com'
   api_version             '1.0'
   debug                   0 (1 will print all kinds of stuff)

=item $mnb->Timeout( int $timeout )

sets timeout for results

=item $mnb->Campaigns( %filters )

returns an array of hashrefs listing campaigns.  Optional key/value pair argument allows you to filter results:

   KEY                     OPTIONS
   ___________             ____________________
   status                  draft, sent, scheduled, all(default)
   archived                1, 0
   published               1, 0

returned hashrefs are in the following format:

   KEY                     DESCRIPTION
   ___________             ____________________
   id                      numeric id for campaign
   name                    campaign's name
   description             campaign's description
   published               1 if campaign published 0 if not
   archived                1 if campaign archied 0 if not
   status                  status will be draft, sent or scheduled

=item $mnb->CampaignDetails( int $id )

requires a campaign id and returns a hashref containing a campaign's details with the following keys:

   KEY                     DESCRIPTION
   ___________             ____________________
   reply_name              name for reply to
   reply_email             email address for reply to
   from_name               name for from
   from_email              email address for from
   subject                 email subject
   html                    email html body
   text                    email text body

=item $mnb->CampaignCreate( string $name, string $subject, \%from, \%reply, string $html, string $text, bool $link_tracking, bool $gat )

requires a whole bunch of stuff and returns an id. arguments:

    string $name -- Internal campaign name
    string $subject -- Campaign subject line
    hashref $from -- keys are 'name' and 'email'
    hashref $reply -- keys are 'name' and 'email' (if empty $from is used)
    string $html -- HTML content for the campaign.
    string $text -- the text content for the campaign. (defaults to a stripped version of $html)
    bool $link_tracking -- 0 turn off link tracking 1(default) turns it on
    bool $gat -- 0(default) turns off Google Analytics Tracking 1 turns it on

=item $mnb->CampaignUpdate( int $id, \%details )

requires an int id and hashref details returns 1 if successful and 0 on failure. hashref format:

   KEY                     DESCRIPTION
   ___________             ____________________
   name                    Internal campaign name
   subject                 Campaign subject line
   from                    hashref with keys 'name' and 'email'
   reply                   hashref with keys are 'name' and 'email' (if empty $from is used)
   html                    HTML content for the campaign.
   text                    the text content for the campaign.
   link_tracking           0 turn off link tracking 1(default) turns it on
   gat                     0(default) turns off Google Analytics Tracking 1 turns it on

=item $mnb->CampaignCopy( int $id, string $name )

takes an id and name copies an existing campaign identified by id and returns the new id.  original name will be reused if name is ommitted.

=item $mnb->CampaignDelete( int $id )

takes an id and deletes campaign idenified by that id. returns 1 on success and 0 on failure.

=item $mnb->CampaignSchedule( int $id, string $when, \@lists, bool $smart, bool $confirmed )

schedules a Campaign for sending based on arguments:

    int $id -- campaign id to send
    datetime $when -- date/time to send this can be in any format readable by PHP's strtotime() function and will be EST.
    array @lists -- flat array of list id's the campaign should go out to
    bool $smart -- 0(default) disables smart send 1 enables it. see http://help.mynewsletterbuilder.com/Help_Pop-up_for_Newsletter_Scheduler
    bool $confirmed -- 0(default) sends to all subscribers 1 sends to only confirmed
    
returns 0 on failure and 1 on success.

=item $mnb->CampaignStats( int $id )

takes a campaign id and returns stats for that campaign. returned hahsref has the following keys:

   KEY                     DESCRIPTION
   ___________             ____________________
   id                      numeric id for campaign
   clicks                  number of clicks
   clicks_unique           number of unique clicks
   forwards                number of forwards
   forwards_unique         number of unique forwards
   opens                   number of opens
   opens_unique            number of unique opens
   recipients              number of recipients
   bounces                 number of bounces
   delivered               number delivered
   complaints              number of complaints
   subscribes              number of subscribes
   unsubscribes            number of unsubscribes
   sent_on                 date and time campaign sent ('2010-03-04 01:30:47' EST)
   first_open              date and time of first open ('2010-03-04 01:30:47' EST)
   last_open               date and time of last open ('2010-03-04 01:30:47' EST)
   archived                1 if archived 0 if not

=item $mnb->CampaignRecipients( int $id, int $page, int $limit)

takes a campaign id, an optional page number and limit (for paging systems on large data sets) and returns an array of hashrefs containing data about subscribers in the format:

   KEY                     DESCRIPTION
   ___________             ____________________
   id                      numeric id of subscriber
   email                   email address of subscriber
   processed               when campaign was sent to subscriber ('2010-03-04 01:30:47' EST)

=item $mnb->CampaignOpens( int $id, int $page, int $limit)

takes a campaign id, an optional page number and limit (for paging systems on large data sets) and returns an array of hashrefs containing data about subscribers who have opened the campaign in the format:

   KEY                     DESCRIPTION
   ___________             ____________________
   id                      numeric id of subscriber
   email                   email address of subscriber
   count                   number of opens
   first_open              date and time subscriber first opened campaign ('2010-03-04 01:30:47' EST)
   last_open               date and time subscriber last opened campaign ('2010-03-04 01:30:47' EST)

=item $mnb->CampaignBounces( int $id, int $page, int $limit)

takes a campaign id, an optional page number and limit (for paging systems on large data sets) and returns an array of hashrefs containing data about subscribers who bounced in the format:

   KEY                     DESCRIPTION
   ___________             ____________________
   id                      numeric id of subscriber
   email                   email address of subscriber
   processed               when mnb processed bounce from subscriber ('2010-03-04 01:30:47' EST)

=item $mnb->CampaignClicks( int $id, int $page, int $limit)

takes a campaign id, an optional page number and limit (for paging systems on large data sets) and returns an array of hashrefs containing data about subscribers who clicked links in the format:

   KEY                     DESCRIPTION
   ___________             ____________________
   id                      numeric id of subscriber
   email                   email address of subscriber

=item $mnb->CampaignClickDetails( int $id, int $url_id, int $page, int $limit)

takes a campaign id, url id and optional page number and limit (for paging systems on large data sets) and returns an array of hashrefs containing data about subscribers who clicked links in the format:

   KEY                     DESCRIPTION
   ___________             ____________________
   id                      numeric id of subscriber
   email                   email address of subscriber
   count                   number of times subscriber clicked link
   url_id                  url id of link clicked

=item $mnb->CampaignSubscribes( int $id, int $page, int $limit)

takes a campaign id, an optional page number and limit (for paging systems on large data sets) and returns an array of hashrefs containing data about subscribers who subscribed based on this campaign in the format:

   KEY                     DESCRIPTION
   ___________             ____________________
   id                      numeric id of subscriber
   email                   email address of subscriber
   processed               when subscriber was processed

=item $mnb->CampaignUnsubscribes( int $id, int $page, int $limit)

takes a campaign id, an optional page number and limit (for paging systems on large data sets) and returns an array of hashrefs containing data about subscribers who unsubscribed in the format:

   KEY                     DESCRIPTION
   ___________             ____________________
   id                      numeric id of subscriber
   email                   email address of subscriber
   processed               when subscriber was processed

=item $mnb->CampaignUrls( int $id )

takes a campaign id and returns an array of hashrefs with link related data in the format:

   KEY                     DESCRIPTION
   ___________             ____________________
   url_id                  numeric id of url
   link                    FQDN for link
   unique                  number of unique clicks
   total                   number of total clicks
   title                   text within link (can include html including img tags)

=item $mnb->Lists( )

returns an array hasrefs of subscriber lists with the following keys:

   KEY                     DESCRIPTION
   ___________             ____________________
   id                      numeric id for list
   name                    list name
   description             list description
   hidden                  1 if hidden 0 if not
   default                 1 if default 0 if not
   subscribers             number of subscribers in list

=item $mnb->ListCreate( string $name, string $description, bool $visible, bool $default )

takes several arguments, creates a new subscriber list and returns it's unique id. arguments:

    string $name -- name for new list
    string $description -- description for new list
    bool $visible -- 1 if list is visible 0(default) if not
    bool $default -- 1 if list is default 0(default) if not

=item $mnb->ListUpdate( int $id, \%details )

takes an id and a hashref of details (only id is required though we won't actually do anything without something in the details hashref), updates the subscriber list identified by id and returns 1 on success and 0 on failure.

details hashref format:

   KEY                     DESCRIPTION
   ___________             ____________________
   name                    new name for list
   description             new description for list
   visible                 1 if list is visible 0(default) if not
   default                 1 if list is default 0(default) if not

=item $mnb->ListDelete( int $id, bool $delete_subs )

deletes the list identified by id.  if $delete_subs is 1 all subscribers in list are deleted as well.  if delete_subs is 0(default) we don't touch subscribers.  returns 1 on success and 0 on failure.

=item $mnb->Subscribe( \%details, \@lists, bool $skip_opt_in, bool $update_existing )

sets up a single subscriber based on %details. if @lists is populated it OVERRIDES a current users current set of lists.  if it is empty no changes are made to existing users.  skip_opt_in is used to enable confirmation email (default is 0). update_existing is used to specify that you want %details to overrid an existing user's info.  it will NOT be applied to lists.  if lists is populated an existing user's lists WILL be overridden even with the update_existing flag set. it defaults to true.

%details is a hashref with the following format:

   KEY                             DESCRIPTION
   ___________                     ____________________
   email                           subscriber email address
   first_name                      subscriber first name
   middle_name                     subscriber middle name
   last_name                       subscriber last name
   company_name                    subscriber company name
   job_title                       subscribers job title
   phone_work                      subscriber work phone
   phone_home                      subscriber home phone
   address_1                       first line of address
   address_2                       second line of address
   address_3                       third line of address
   city                            city of address
   state                           state of address
   zip                             postal code
   country                         country part of address
   
   custom field names              custom field values

custom fields can be set by using their full name as the key and their value as the value... again this can lead to keys with spaces.

Subscribe() returns a hashref with the following keys:

   KEY                             DESCRIPTION
   ___________                     ____________________
   id                              subscriber's unique id
   email                           subscriber's uniqe email
   status                          status of subscription.  possible values are new, updated, error, ignored
   status_msg                      contains text message about update... usually only used for errors

=item $mnb->SubscribeBatch( \@subscribers, \@lists, bool $skip_opt_in, bool $update_existing )

sets up multiple subscriber based on @subscribers which is an array of hashrefs. if @lists is populated it OVERRIDES any current users set of lists.  if it is empty no changes are made to existing users.  skip_opt_in is used to enable confirmation email (default is 0). update_existing is used to specify that you want %details to overrid an existing user's info.  it will NOT be applied to lists.  if lists is populated an existing user's lists WILL be overridden even with the update_existing flag set. it defaults to true.

@subscribers is an array of hashrefs with the following format:

   KEY                             DESCRIPTION
   ___________                     ____________________
   email                           subscriber email address
   first_name                      subscriber first name
   middle_name                     subscriber middle name
   last_name                       subscriber last name
   company_name                    subscriber company name
   job_title                       subscribers job title
   phone_work                      subscriber work phone
   phone_home                      subscriber home phone
   address_1                       first line of address
   address_2                       second line of address
   address_3                       third line of address
   city                            city of address
   state                           state of address
   zip                             postal code
   country                         country part of address
   
   custom field names              custom field values

custom fields can be set by using their full name as the key and their value as the value... again this can lead to keys with spaces.

SubscribeBatch() returns a hashref with the following keys:

	KEY                             DESCRIPTION
   ___________                     ____________________
   meta                            contains a hashref with overview info described below
   subscribers                     contains an array of hashrefs described below. this will match the order of the @subscribers array you submitted

the meta key of the return from SubscribeBatch() contains a hashref with the following keys:

   KEY                             DESCRIPTION
   ___________                     ____________________
   total                           total count of attempted subscribes
   success                         total count of successful subscribes
   errors                          total count of subscribes with errors
   
the subscribers key of the return from SubscribeBatch() contains an array of hashrefs with the following keys:

   KEY                             DESCRIPTION
   ___________                     ____________________
   id                              subscriber's unique id
   email                           subscriber's uniqe email
   status                          status of subscription.  possible values are new, updated, error, ignored
   status_msg                      contains text message about update... usually only used for errors


=item $mnb->SubscriberInfo( string $id_or_email )

takes an argument that can be either the unique id for the subscriber or an email address and returns a hashref of subscriber data in the following format:

   KEY                             DESCRIPTION
   ___________                     ____________________
   id                              numeric id for subscriber
   email                           subscriber email address
   full_name                       subscriber full name
   first_name                      subscriber first name
   middle_name                     subscriber middle name
   last_name                       subscriber last name
   company_name                    subscriber company name
   job_title                       subscribers job title
   phone_work                      subscriber work phone
   phone_home                      subscriber home phone
   address_1                       first line of address
   address_2                       second line of address
   address_3                       third line of address
   city                            city of address
   state                           state of address
   zip                             postal code
   country                         country part of address (may be improperly formatted)
   campaign_id                     if subscriber subscribed from a campaign it's id is here
   lists                           contains a flat array containing the lists the user is in
   last_confirmation_request       last time we sent a confirmation to the user
   confirmed_date                  date subscriber confirmed
   confirmed_from                  ip address user confirmed from
   add_remove_date                 date subscriber status changed
   status                          current status possible values: active, unsubscribed, deleted, list_too_small
   add_method                      who last updated the user possible values: U - user added, S - added self, A - Admin added, C - added by complaint system, B - added by bounce management system
   confirmed                       status of confirmation (confirmed, unconfirmed, pending)
   
   custom field names              custom field values

custom fields will come back in this hashref with their names as keys and their values as the value.  this means there is a possiblity that keys will have spaces in them.  sorry.

=item $mnb->SubscriberUpdate( string $id_or_email, \%details, \@lists )

takes an argument that can be either the unique id for the subscriber or an email address and updates a subscribers info and lists based on details hashref and lists arrayref. if @lists is empty NO CHANGES ARE MADE TO A USERS LISTS.  use SubscriberDelete or SubscriberUnsubscribe to remove a subscriber from all lists.

%details is a hashref with the following format:

   KEY                             DESCRIPTION
   ___________                     ____________________
   id                              numeric id for subscriber
   email                           subscriber email address
   full_name                       subscriber full name
   first_name                      subscriber first name
   middle_name                     subscriber middle name
   last_name                       subscriber last name
   company_name                    subscriber company name
   job_title                       subscribers job title
   phone_work                      subscriber work phone
   phone_home                      subscriber home phone
   address_1                       first line of address
   address_2                       second line of address
   address_3                       third line of address
   city                            city of address
   state                           state of address
   zip                             postal code
   country                         country part of address
   
   custom field names              custom field values

custom fields can be set by using their full name as the key and their value as the value... again this can lead to keys with spaces.


=item $mnb->SubscriberUnsubscribe( string $id_or_email )

takes an argument that can be either the unique id for the subscriber or an email address and permanantly removes that subscriber for the user identified by your api_key.  this subscribers will NOT be able to be readded by SubscribeBatch().

returns 1 on success and 0 on failure.

=item $mnb->SubscriberUnsubscribeBatch( \@ids_or_emails )

takes an argument that is an array containing either the unique ids for the subscriber or an email address and permanantly removes those subscribesr for the user identified by your api_key.  these subscribers will NOT be able to be readded by SubscribeBatch().

returns 1 on success and 0 on failure.

=item $mnb->SubscriberDelete( string $id_or_email )

takes an argument that can be either the unique id for the subscriber or an email address and removes that subscriber for the user identified by your api_key.  this subscriber WILL be readded if their email address is re-submitted to Subscribe() or SubscribeBatch().

returns 1 on success and 0 on failure.

=item $mnb->SubscriberDeleteBatch( \@ids_or_emails )

takes an argument that is an array containing either the unique id for subscribers or an email addresss and removes the subscribers for the user identified by your api_key. these subscribers WILL be readded if their email addresses are re-submitted to Subscribe() or SubscribeBatch().

returns 1 on success and 0 on failure.

=item $mnb->AccountKeys( string $username, string $password, bool $disabled)

takes the user's username and password and returns data on available api keys.  if $disabled(default 0) is 1 list will include disabled keys.

return is an array of hashrefs with the following keys:

   KEY                             DESCRIPTION
   ___________                     ____________________
   id                              unique numeric id of key
   key                             unique key string
   created                         date key created
   expired                         date key expired or was disabled (null for valid key)

=item $mnb->AccountKeyCreate( string $username, string $password )

takes the user's username and password creates a key and returns data about created key.  return is a hashref with the following keys:

   KEY                             DESCRIPTION
   ___________                     ____________________
   id                              unique numeric id of key
   key                             unique key string
   create                          date key created
   expired                         date key expired or was disabled (null for valid key)

=item $mnb->AccountKeyDisable( string $username, string $password, string $id_or_key )

takes the user's username and password and an id or existing key it disables the referenced key and returns 1 on success and an error on failure.

=item $mnb->AccountKeyEnable( string $username, string $password, string $id_or_key )

takes the user's username and password and an id or existing key it enables the referenced key and returns 1 on success and an error on failure.

=item $mnb->HelloWorld( string $value )

takes a value and echos it back from the API server.

=back

=head2 EXPORT

None by default.

=head2 REQUIREMENTS

Frontier::Client

=head1 SEE ALSO

http://api.mynewsletterbuilder.com

=head1 AUTHOR

Robert Davis, robert@jbanetwork.com

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by JBA Network (http://www.jbanetwork.com)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut