#============================================================= -*-perl-*-
#
# BackupPC::CGI::Lib package
#
# DESCRIPTION
#
#   This library defines a BackupPC::Lib class and a variety of utility
#   functions used by BackupPC.
#
# AUTHOR
#   Craig Barratt  <cbarratt@users.sourceforge.net>
#
# COPYRIGHT
#   Copyright (C) 2003  Craig Barratt
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#========================================================================
#
# Version 2.1.0_CVS, released 3 Jul 2003.
#
# See http://backuppc.sourceforge.net.
#
#========================================================================

package BackupPC::CGI::Lib;

use strict;
use BackupPC::Lib;

require Exporter;

use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS );

use vars qw($Cgi %In $MyURL $User %Conf $TopDir $BinDir $bpc);
use vars qw(%Status %Info %Jobs @BgQueue @UserQueue @CmdQueue
            %QueueLen %StatusHost);
use vars qw($Hosts $HostsMTime $ConfigMTime $PrivAdmin);
use vars qw(%UserEmailInfo $UserEmailInfoMTime %RestoreReq);
use vars qw($Lang);

@ISA = qw(Exporter);

@EXPORT    = qw( );

@EXPORT_OK = qw(
		    timeStamp2
		    HostLink
		    UserLink
		    EscHTML
		    EscURI
		    ErrorExit
		    ServerConnect
		    GetStatusInfo
		    ReadUserEmailInfo
		    CheckPermission
		    GetUserHosts
		    ConfirmIPAddress
		    Header
		    Trailer
		    NavSectionTitle
		    NavSectionStart
		    NavSectionEnd
		    NavLink
		    h1
		    h2
		    $Cgi %In $MyURL $User %Conf $TopDir $BinDir $bpc
		    %Status %Info %Jobs @BgQueue @UserQueue @CmdQueue
		    %QueueLen %StatusHost
		    $Hosts $HostsMTime $ConfigMTime $PrivAdmin
		    %UserEmailInfo $UserEmailInfoMTime %RestoreReq
		    $Lang
             );

%EXPORT_TAGS = (
    'all'    => [ @EXPORT_OK ],
);

sub NewRequest
{
    $Cgi = new CGI;
    %In = $Cgi->Vars;

    #
    # Default REMOTE_USER so in a miminal installation the user
    # has a sensible default.
    #
    $ENV{REMOTE_USER} = $Conf{BackupPCUser} if ( !defined($ENV{REMOTE_USER}) );

    #
    # We require that Apache pass in $ENV{SCRIPT_NAME} and $ENV{REMOTE_USER}.
    # The latter requires .ht_access style authentication.  Replace this
    # code if you are using some other type of authentication, and have
    # a different way of getting the user name.
    #
    $MyURL  = $ENV{SCRIPT_NAME};
    $User   = $ENV{REMOTE_USER};

    if ( !defined($bpc) ) {
	ErrorExit($Lang->{BackupPC__Lib__new_failed__check_apache_error_log})
	    if ( !($bpc = BackupPC::Lib->new(undef, undef, 1)) );
	$TopDir = $bpc->TopDir();
	$BinDir = $bpc->BinDir();
	%Conf   = $bpc->Conf();
	$Lang   = $bpc->Lang();
	$ConfigMTime = $bpc->ConfigMTime();
    } elsif ( $bpc->ConfigMTime() != $ConfigMTime ) {
	$bpc->ConfigRead();
	%Conf   = $bpc->Conf();
	$ConfigMTime = $bpc->ConfigMTime();
	$Lang   = $bpc->Lang();
    }

    #
    # Clean up %ENV for taint checking
    #
    delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};
    $ENV{PATH} = $Conf{MyPath};

    #
    # Verify we are running as the correct user
    #
    if ( $Conf{BackupPCUserVerify}
	    && $> != (my $uid = (getpwnam($Conf{BackupPCUser}))[2]) ) {
	ErrorExit(eval("qq{$Lang->{Wrong_user__my_userid_is___}}"), <<EOF);
This script needs to run as the user specified in \$Conf{BackupPCUser},
which is set to $Conf{BackupPCUser}.
<p>
This is an installation problem.  If you are using mod_perl then
it appears that Apache is not running as user $Conf{BackupPCUser}.
If you are not using mod_perl, then most like setuid is not working
properly on BackupPC_Admin.  Check the permissions on
$Conf{CgiDir}/BackupPC_Admin and look at the documentation.
EOF
    }

    if ( !defined($Hosts) || $bpc->HostsMTime() != $HostsMTime ) {
	$HostsMTime = $bpc->HostsMTime();
	$Hosts = $bpc->HostInfoRead();

	# turn moreUsers list into a hash for quick lookups
	foreach my $host (keys %$Hosts) {
	   $Hosts->{$host}{moreUsers} =
	       {map {$_, 1} split(",", $Hosts->{$host}{moreUsers}) }
	}
    }
}

sub timeStamp2
{
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
              = localtime($_[0] == 0 ? time : $_[0] );
    $mon++;
    if ( $Conf{CgiDateFormatMMDD} ) {
        return sprintf("$mon/$mday %02d:%02d", $hour, $min);
    } else {
        return sprintf("$mday/$mon %02d:%02d", $hour, $min);
    }
}

sub HostLink
{
    my($host) = @_;
    my($s);
    if ( defined($Hosts->{$host}) || defined($Status{$host}) ) {
        $s = "<a href=\"$MyURL?host=${EscURI($host)}\">$host</a>";
    } else {
        $s = $host;
    }
    return \$s;
}

sub UserLink
{
    my($user) = @_;
    my($s);

    return \$user if ( $user eq ""
                    || $Conf{CgiUserUrlCreate} eq "" );
    if ( $Conf{CgiUserHomePageCheck} eq ""
            || -f sprintf($Conf{CgiUserHomePageCheck}, $user, $user, $user) ) {
        $s = "<a href=\""
             . sprintf($Conf{CgiUserUrlCreate}, $user, $user, $user)
             . "\">$user</a>";
    } else {
        $s = $user;
    }
    return \$s;
}

sub EscHTML
{
    my($s) = @_;
    $s =~ s/&/&amp;/g;
    $s =~ s/\"/&quot;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/</&lt;/g;
    $s =~ s{([^[:print:]])}{sprintf("&\#x%02X;", ord($1));}eg;
    return \$s;
}

sub EscURI
{
    my($s) = @_;
    $s =~ s{([^\w.\/-])}{sprintf("%%%02X", ord($1));}eg;
    return \$s;
}

sub ErrorExit
{
    my(@mesg) = @_;
    my($head) = shift(@mesg);
    my($mesg) = join("</p>\n<p>", @mesg);
    $Conf{CgiHeaderFontType} ||= "arial"; 
    $Conf{CgiHeaderFontSize} ||= "3";  
    $Conf{CgiNavBarBgColor}  ||= "#ddeeee";
    $Conf{CgiHeaderBgColor}  ||= "#99cc33";

    if ( !defined($ENV{REMOTE_USER}) ) {
	$mesg .= <<EOF;
<p>
Note: \$ENV{REMOTE_USER} is not set, which could mean there is an
installation problem.  BackupPC_Admin expects Apache to authenticate
the user and pass their user name into this script as the REMOTE_USER
environment variable.  See the documentation.
EOF
    }

    $bpc->ServerMesg("log User $User (host=$In{host}) got CGI error: $head")
                            if ( defined($bpc) );
    if ( !defined($Lang->{Error}) ) {
	Header("BackupPC: Error");
        $mesg = <<EOF if ( !defined($mesg) );
There is some problem with the BackupPC installation.
Please check the permissions on BackupPC_Admin.
EOF
	print <<EOF;
${h1("Error: Unable to read config.pl or language strings!!")}
<p>$mesg</p>
EOF
	Trailer();
    } else {
	Header(eval("qq{$Lang->{Error}}"));
	print (eval("qq{$Lang->{Error____head}}"));
	Trailer();
    }
    exit(1);
}

sub ServerConnect
{
    #
    # Verify that the server connection is ok
    #
    return if ( $bpc->ServerOK() );
    $bpc->ServerDisconnect();
    if ( my $err = $bpc->ServerConnect($Conf{ServerHost}, $Conf{ServerPort}) ) {
        ErrorExit(eval("qq{$Lang->{Unable_to_connect_to_BackupPC_server}}"));
    }
}

sub GetStatusInfo
{
    my($status) = @_;
    ServerConnect();
    my $reply = $bpc->ServerMesg("status $status");
    $reply = $1 if ( $reply =~ /(.*)/s );
    eval($reply);
    # ignore status related to admin and trashClean jobs
    if ( $status =~ /\bhosts\b/ ) {
        delete($Status{$bpc->adminJob});
        delete($Status{$bpc->trashJob});
    }
}

sub ReadUserEmailInfo
{
    if ( (stat("$TopDir/log/UserEmailInfo.pl"))[9] != $UserEmailInfoMTime ) {
        do "$TopDir/log/UserEmailInfo.pl";
        $UserEmailInfoMTime = (stat("$TopDir/log/UserEmailInfo.pl"))[9];
    }
}

#
# Check if the user is privileged.  A privileged user can access
# any information (backup files, logs, status pages etc).
#
# A user is privileged if they belong to the group
# $Conf{CgiAdminUserGroup}, or they are in $Conf{CgiAdminUsers}
# or they are the user assigned to a host in the host file.
#
sub CheckPermission
{
    my($host) = @_;
    my $Privileged = 0;

    return 0 if ( $User eq "" && $Conf{CgiAdminUsers} ne "*"
	       || $host ne "" && !defined($Hosts->{$host}) );
    if ( $Conf{CgiAdminUserGroup} ne "" ) {
        my($n,$p,$gid,$mem) = getgrnam($Conf{CgiAdminUserGroup});
        $Privileged ||= ($mem =~ /\b$User\b/);
    }
    if ( $Conf{CgiAdminUsers} ne "" ) {
        $Privileged ||= ($Conf{CgiAdminUsers} =~ /\b$User\b/);
        $Privileged ||= $Conf{CgiAdminUsers} eq "*";
    }
    $PrivAdmin = $Privileged;
    $Privileged ||= $User eq $Hosts->{$host}{user};
    $Privileged ||= defined($Hosts->{$host}{moreUsers}{$User});

    return $Privileged;
}

#
# Returns the list of hosts that should appear in the navigation bar
# for this user.  If $Conf{CgiNavBarAdminAllHosts} is set, the admin
# gets all the hosts.  Otherwise, regular users get hosts for which
# they are the user or are listed in the moreUsers column in the
# hosts file.
#
sub GetUserHosts
{
    if ( $Conf{CgiNavBarAdminAllHosts} && CheckPermission() ) {
       return sort keys %$Hosts;
    }

    return sort grep { $Hosts->{$_}{user} eq $User ||
                       defined($Hosts->{$_}{moreUsers}{$User}) } keys(%$Hosts);
}

#
# Given a host name tries to find the IP address.  For non-dhcp hosts
# we just return the host name.  For dhcp hosts we check the address
# the user is using ($ENV{REMOTE_ADDR}) and also the last-known IP
# address for $host.  (Later we should replace this with a broadcast
# nmblookup.)
#
sub ConfirmIPAddress
{
    my($host) = @_;
    my $ipAddr = $host;

    if ( defined($Hosts->{$host}) && $Hosts->{$host}{dhcp}
	       && $ENV{REMOTE_ADDR} =~ /^(\d+[\.\d]*)$/ ) {
	$ipAddr = $1;
	my($netBiosHost, $netBiosUser) = $bpc->NetBiosInfoGet($ipAddr);
	if ( $netBiosHost ne $host ) {
	    my($tryIP);
	    GetStatusInfo("host(${EscURI($host)})");
	    if ( defined($StatusHost{dhcpHostIP})
			&& $StatusHost{dhcpHostIP} ne $ipAddr ) {
		$tryIP = eval("qq{$Lang->{tryIP}}");
		($netBiosHost, $netBiosUser)
			= $bpc->NetBiosInfoGet($StatusHost{dhcpHostIP});
	    }
	    if ( $netBiosHost ne $host ) {
		ErrorExit(eval("qq{$Lang->{Can_t_find_IP_address_for}}"),
		          eval("qq{$Lang->{host_is_a_DHCP_host}}"));
	    }
	    $ipAddr = $StatusHost{dhcpHostIP};
	}
    }
    return $ipAddr;
}

###########################################################################
# HTML layout subroutines
###########################################################################

sub Header
{
    my($title) = @_;
    my @adminLinks = (
        { link => "",                          name => $Lang->{Status},
                                               priv => 1},
        { link => "?action=summary",           name => $Lang->{PC_Summary} },
        { link => "?action=view&type=LOG",     name => $Lang->{LOG_file} },
        { link => "?action=LOGlist",           name => $Lang->{Old_LOGs} },
        { link => "?action=emailSummary",      name => $Lang->{Email_summary} },
        { link => "?action=view&type=config",  name => $Lang->{Config_file} },
        { link => "?action=view&type=hosts",   name => $Lang->{Hosts_file} },
        { link => "?action=queue",             name => $Lang->{Current_queues} },
        { link => "?action=view&type=docs",    name => $Lang->{Documentation},
                                               priv => 1},
        { link => "http://backuppc.sourceforge.net/faq", name => "FAQ",
                                               priv => 1},
        { link => "http://backuppc.sourceforge.net", name => "SourceForge",
                                               priv => 1},
    );
    print $Cgi->header();
    print <<EOF;
<!doctype html public "-//W3C//DTD HTML 4.01 Transitional//EN">
<html><head>
<title>$title</title>
$Conf{CgiHeaders}
</head><body bgcolor="$Conf{CgiBodyBgColor}">
<table cellpadding="0" cellspacing="0" border="0">
<tr valign="top"><td valign="top" bgcolor="$Conf{CgiNavBarBgColor}" width="10%">
EOF
    NavSectionTitle("BackupPC");
    print "&nbsp;\n";
    if ( defined($In{host}) && defined($Hosts->{$In{host}}) ) {
        my $host = $In{host};
        NavSectionTitle( eval("qq{$Lang->{Host_Inhost}}") );
        NavSectionStart();
        NavLink("?host=${EscURI($host)}", $Lang->{Home});
        NavLink("?action=view&type=LOG&host=${EscURI($host)}", $Lang->{LOG_file});
        NavLink("?action=LOGlist&host=${EscURI($host)}", $Lang->{Old_LOGs});
        if ( -f "$TopDir/pc/$host/SmbLOG.bad"
                    || -f "$TopDir/pc/$host/SmbLOG.bad.z"
                    || -f "$TopDir/pc/$host/XferLOG.bad"
                    || -f "$TopDir/pc/$host/XferLOG.bad.z" ) {
            NavLink("?action=view&type=XferLOGbad&host=${EscURI($host)}",
                                $Lang->{Last_bad_XferLOG});
            NavLink("?action=view&type=XferErrbad&host=${EscURI($host)}",
                                $Lang->{Last_bad_XferLOG_errors_only});
        }
        if ( -f "$TopDir/pc/$host/config.pl" ) {
            NavLink("?action=view&type=config&host=${EscURI($host)}", $Lang->{Config_file});
        }
        NavSectionEnd();
    }
    NavSectionTitle($Lang->{NavSectionTitle_});
    NavSectionStart();
    foreach my $l ( @adminLinks ) {
        if ( $PrivAdmin || $l->{priv} ) {
            NavLink($l->{link}, $l->{name});
        } else {
            NavLink(undef, $l->{name});
        }
    }
    NavSectionEnd();
    NavSectionTitle($Lang->{Hosts});
    print <<EOF;
<table cellpadding="2" cellspacing="0" border="0" width="100%">
    <tr><td>$Lang->{Host_or_User_name}</td>
    <tr><td><form action="$MyURL" method="get"><small>
    <input type="text" name="host" size="10" maxlength="64">
    <input type="hidden" name="action" value="hostInfo"><input type="submit" value="$Lang->{Go}" name="ignore">
    </small></form></td></tr>
</table>
EOF
    if ( defined($Hosts) && %$Hosts > 0 ) {
        NavSectionStart(1);
        foreach my $host ( GetUserHosts() ) {
            NavLink("?host=${EscURI($host)}", $host);
        }
        NavSectionEnd();
    }
    print <<EOF;
</td><td valign="top" width="5">&nbsp;&nbsp;</td>
<td valign="top" width="90%">
EOF
}

sub Trailer
{
    print <<EOF;
</td></table>
</body></html>
EOF
}


sub NavSectionTitle
{
    my($head) = @_;
    print <<EOF;
<table cellpadding="2" cellspacing="0" border="0" width="100%">
<tr><td bgcolor="$Conf{CgiHeaderBgColor}"><font face="$Conf{CgiHeaderFontType}"
size="$Conf{CgiHeaderFontSize}"><b>$head</b>
</font></td></tr>
</table>
EOF
}

sub NavSectionStart
{
    my($padding) = @_;

    $padding = 1 if ( !defined($padding) );
    print <<EOF;
<table cellpadding="$padding" cellspacing="0" border="0" width="100%">
EOF
}

sub NavSectionEnd
{
    print "</table>\n";
}

sub NavLink
{
    my($link, $text) = @_;
    print "<tr><td width=\"2%\" valign=\"top\"><b>&middot;</b></td>";
    if ( defined($link) ) {
        $link = "$MyURL$link" if ( $link eq "" || $link =~ /^\?/ );
        print <<EOF;
<td width="98%"><a href="$link"><small>$text</small></a></td></tr>
EOF
    } else {
        print <<EOF;
<td width="98%"><small>$text</small></td></tr>
EOF
    }
}

sub h1
{
    my($str) = @_;
    return \<<EOF;
<table cellpadding="2" cellspacing="0" border="0" width="100%">
<tr>
<td bgcolor="$Conf{CgiHeaderBgColor}">&nbsp;<font face="$Conf{CgiHeaderFontType}"
    size="$Conf{CgiHeaderFontSize}"><b>$str</b></font>
</td></tr>
</table>
EOF
}

sub h2
{
    my($str) = @_;
    return \<<EOF;
<table cellpadding="2" cellspacing="0" border="0" width="100%">
<tr>
<td bgcolor="$Conf{CgiHeaderBgColor}">&nbsp;<font face="$Conf{CgiHeaderFontType}"
    size="$Conf{CgiHeaderFontSize}"><b>$str</b></font>
</td></tr>
</table>
EOF
}