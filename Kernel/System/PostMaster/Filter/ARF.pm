# --
# Kernel/System/PostMaster/Filter/ARF.pm - Filter for getting values out of ARF Messages
# http://en.wikipedia.org/wiki/Abuse_Reporting_Format
# 
# needs Email::ARF::Report;
#
# by Jens Bothe 2011-12-15
# jb@otrs.org
#
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --
package Kernel::System::PostMaster::Filter::ARF;
use strict;
use warnings;
use vars qw($VERSION);
use Email::ARF::Report;

$VERSION = qw($Revision: 1.0 $) [1];

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );
    $Self->{Debug} = $Param{Debug} || 0;

    # get needed objects
    foreach (qw(ConfigObject LogObject TicketObject TimeObject ParserObject)) {
        $Self->{$_} = $Param{$_} || die "Got no $_!";
    }

    # Default Settings when no Sysconfig is found
	
    $Self->{Config} = {
		SenderType   	  	=> 'system',
		ArticleType       	=> 'note-report',
 		FromAddressRegExp 	=> 'scomp@aol.net',
 		ReportFeedbackType 	=> '1',
 		ReportSourceIP 		=> '2',
 		OrigTo 			=> '3',
 		OrigFrom 		=> '4',
 		OrigSubject	 	=> '5',
 		OrigMessageID 		=> '6',
    };
    return $Self;
}

sub Run {
    my $Self       = shift;
    my %Param      = @_;
    my $LogMessage = '';

   # get config options from sysconfig
	# only use defaults unless no value specified
    if ( $Param{JobConfig} && ref( $Param{JobConfig} ) eq 'HASH' ) {
        foreach ( keys( %{ $Param{JobConfig} } ) ) {
            $Self->{Config}{$_}
                && ( $Self->{Config}{$_} = $Param{JobConfig}->{$_} );
        }
    }

	# check if sender is of interest
	# {GetParam}->{From} shows us the Sender Address
	# First check: is there a sender address AND is this address from interest (FromAddressRegexp)
    if (   $Param{GetParam}->{From} && $Param{GetParam}->{From} =~ /$Self->{Config}{FromAddressRegExp}/i )
    {

        $LogMessage = 'From found, start processing';
	# Get Mail Body to work with
	#my $message = $Param{GetParam}->{Body};
	my $message = $Self->{ParserObject}->GetPlainEmail();
	my $report = Email::ARF::Report->new($message);
	# Get the values from the report
	my $feedbacktype = $report->field('Feedback-Type');
	my $sourceip = $report->field('Source-IP');
	# get values of SPAM mail 
	my $origto = $report->original_email->header('to');
	my $origfrom = $report->original_email->header('from');
	my $origsubject = $report->original_email->header('subject');
	my $origmessageid = $report->original_email->header('message-id');
	# write Freefields
 	$Param{GetParam}->{ 'X-OTRS-TicketKey' . $Self->{Config}{ReportFeedbackType}} = 'Feedback-Type';
        $Param{GetParam}->{ 'X-OTRS-TicketValue' . $Self->{Config}{ReportFeedbackType}} = $feedbacktype;

 	$Param{GetParam}->{ 'X-OTRS-TicketKey' . $Self->{Config}{ReportSourceIP}} = 'Source IP';
        $Param{GetParam}->{ 'X-OTRS-TicketValue' . $Self->{Config}{ReportSourceIP}} = $sourceip;
	
 	$Param{GetParam}->{ 'X-OTRS-TicketKey' . $Self->{Config}{OrigTo}} = 'Original To';
        $Param{GetParam}->{ 'X-OTRS-TicketValue' . $Self->{Config}{OrigTo}} = $origto;
	
 	$Param{GetParam}->{ 'X-OTRS-TicketKey' . $Self->{Config}{OrigFrom}} = 'Original From';
        $Param{GetParam}->{ 'X-OTRS-TicketValue' . $Self->{Config}{OrigFrom}} = $origfrom;
	
 	$Param{GetParam}->{ 'X-OTRS-TicketKey' . $Self->{Config}{OrigSubject}} = 'Original Subject';
        $Param{GetParam}->{ 'X-OTRS-TicketValue' . $Self->{Config}{OrigSubject}} = $origsubject;
	
 	$Param{GetParam}->{ 'X-OTRS-TicketKey' . $Self->{Config}{OrigMessageID}} = 'Original MessageID';
        $Param{GetParam}->{ 'X-OTRS-TicketValue' . $Self->{Config}{OrigMessageID}} = $origmessageid;

	# Build a better subject
        $Param{GetParam}->{ 'Subject' } = 'Complaint (' . $feedbacktype . ') on message from ' . $origfrom;
        #$Param{GetParam}->{ 'Subject' } = 'Complaint (' . $feedbacktype . ') on ' . $origsubject . ' from ' . $origfrom;

	# Assign Original From as Customer Number 
        $Param{GetParam}->{ 'X-OTRS-CustomerNo' } = $origfrom;

	return 1;
		}
	else
		{
		return 1;
		}
		if ( $LogMessage ) {
			$Self->{LogObject}->Log(
			Priority => 'notice',
			Message => 'ARF: ' . $LogMessage,
			);
			}
	}

1;
