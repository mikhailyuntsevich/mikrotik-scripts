# This script is designed to automatically switch the IPSec shadowing between two ISPs,
# as well as between each other. 

# For the script to work correctly, you need to add the necessary comments
# to each of the ISPs, IPSec tunnels and BGP Peers. 
# Comments for the ISPs - ISP1, ISP2
# Comennts for the IPSec tunnels accordingly - ISP1Tun1, ISP1Tun2, ISP2Tun1, ISP2Tun2  
# Comments for the BGP Peers accordingly - ISP1Tun1, ISP1Tun2, ISP2Tun1, ISP2Tun2


:local scriptName "CheckAWS";
:local scriptState true;
:local testAddress x.x.x.x; # IP Address form AWS internal network (it must always be active to work properly) 
:local pingState;
:local pingAWS;
:local ISP1State;
:local ISP2State;
:local currentTunnel;
:local loopCount 0;

# After boot delay
:if ([/system/resource/get uptime] < 3m) do={
	:log info "System just booted, waiting 3 min";
	:delay 180; 
}

:do {
	# Cheking internet connection
	:while ([ping 8.8.8.8 count=5]=0 && [ping 1.1.1.1 count=5]=0) do={
		:warning "$scriptName: No internet";
		:delay 60;
	}

	# Cheking ISPs route status
	:set loopCount 0;
	:if ($scriptState) do= {
		:do { 
			:set ISP1State (![ip route get [find comment=ISP1] disable]);
		    :set ISP2State (![ip route get [find comment=ISP2] disable]);
			:set loopCount ($loopCount + 1);
			:if ($loopCount != 1) do={ 
				:log info "$scriptName: No active route for check";
				:delay 30;
			}
			:if ($loopCount = 60) do={
				:log error "$scriptName: Stop script - No active route";
				:set scriptState false; 
			}
		} while=(!$ISP1State && !$ISP2State && $scriptState);
	}

	:set loopCount 0;
	:local pingState true;
	:if ($scriptState) do= {

		# Test connection to AWS 
		:set pingAWS ([ping $testAddress interface=bridge interval=1 count=5] = 0);
		
		# Check current tunnel and change to another if there is no connection 
		:if ($pingAWS) do= {
			:set currentTunnel ([ip ipsec peer get [find disabled=no] comment])	
			:if ($ISP1State) do={
				:if ($currentTunnel = "ISP1Tun1") do={
					:ip ipsec peer set [ip ipsec peer find comment=ISP1Tun1] disable=yes;
					:ip ipsec peer set [ip ipsec peer find comment=ISP1Tun2] disable=no;
					:routing bgp peer set [routing bgp peer find comment=ISP1Tun1] disable=yes;
					:routing bgp peer set [routing bgp peer find comment=ISP1Tun2] disable=no;
					:log info "$scriptName: Change peer to ISP1Tun1";
				}
				:if ($currentTunnel = "ISP1Tun2") do={
					:ip ipsec peer set [ip ipsec peer find comment=ISP1Tun1] disable=no;
					:ip ipsec peer set [ip ipsec peer find comment=ISP1Tun2] disable=yes;
					:routing bgp peer set [routing bgp peer find comment=ISP1Tun1] disable=no;
					:routing bgp peer set [routing bgp peer find comment=ISP1Tun2] disable=yes;
					:log info "$scriptName: Change peer to ISP1Tun2";

				}
				:if (($currentTunnel != "ISP1Tun1") && ($currentTunnel != "ISP1Tun2")) do= { :log info "$scriptName: No tunnel on ISP1"; }
			}
			:if ($ISP2State) do={
				:if ($currentTunnel = "ISP2Tun1") do={
					:ip ipsec peer set [ip ipsec peer find comment=ISP2Tun1] disable=yes;
					:ip ipsec peer set [ip ipsec peer find comment=ISP2Tun2] disable=no;
					:routing bgp peer set [routing bgp peer find comment=ISP2Tun1] disable=yes;
					:routing bgp peer set [routing bgp peer find comment=ISP2Tun2] disable=no;
					:log info "$scriptName: Change peer to ISP2Tun1";
				}
				:if ($currentTunnel = "ISP2Tun2") do={
					:ip ipsec peer set [ip ipsec peer find comment=ISP2Tun1] disable=no;
					:ip ipsec peer set [ip ipsec peer find comment=ISP2Tun2] disable=yes;
					:routing bgp peer set [routing bgp peer find comment=ISP2Tun2] disable=no;
					:routing bgp peer set [routing bgp peer find comment=ISP2Tun2] disable=yes;
					:log info "$scriptName: Change peer to ISP2Tun2";
				}
				:if (($currentTunnel != "ISP2Tun1") && ($currentTunnel != "ISP2Tun2")) do= { :log info "$scriptName: No tunnel on ISP2"; }
			}

			:ip ipsec active-peers kill-connections;

			# Wait 1 min for new connections 
			:delay 20; 
			:do {
				:set loopCount ($loopCount + 1);
				:set pingAWS ([ping $testAddress interface=bridge interval=1 count=5] = 0);
				if ($loopCount = 4) do= {
					:set pingState false; 
					:log info "$scriptName: No ping to AWS";
				}
				:delay 10;
			} while=($pingAWS && $pingState);
		}
	}
	:set loopCount 0;

} while=($scriptState);