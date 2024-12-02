if [ "$2" = "" ]; then
echo making a connection to $1>&2
   if [ -f $HOME/.vnc/totp.secret ]; then
echo setting otp >&2
oathtool -bd 8 --totp "$(cat $HOME/.vnc/totp.secret)" >&2
      oathtool -bd 8 --totp "$(cat $HOME/.vnc/totp.secret)"|vncpasswd -f > $HOME/.vnc/passwd
   fi
echo nc $1 >&2
   nc $1
echo closed $1 >&2
else
echo listening on $1 >&2
   nc -ll $1 -e $0 $2
echo finished >&2
fi
