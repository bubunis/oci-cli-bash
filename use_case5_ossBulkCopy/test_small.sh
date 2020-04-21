sleep 2 &

        PID=$!
        i=1
        sp="/-\|"
        echo -n ' '
        while [ -d /proc/$PID ]
        do
                printf "\b${sp:i++%${#sp}:1}"
        done


echo  "\bI AM HERE"

