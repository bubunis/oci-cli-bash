oci os object get -ns ocicustomeropshb -bn Mono-BUCKET-IAD --name SAMPLE100Mb --file /tmp/100MB_FILE &

       PID=$!
        i=1
        sp="/-\|"
        echo -n ' '
        while [ -d /proc/$PID ]
        do
                printf "\b${sp:i++%${#sp}:1}"
        done

echo -e "FILE COPY COMPLETED..."
ls -lrt /tmp/100MB_FILE
rm -f /tmp/100MB_FILE

