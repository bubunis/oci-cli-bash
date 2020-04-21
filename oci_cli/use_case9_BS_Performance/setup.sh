#####
#
#
#
#####

ping -c 1 raw.githubusercontent.com 1>/dev/null 2>/dev/null
if [ $? -ne 0 ]; then
        echo "SEEMS THIS SERVER IS UNABLE TO REACH THE oci-cli INSTALLATION SERVER.Quitting.."
	exit 0;
fi
#bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
exec -l $SHELL
oci cli config
