# prompt
A web/git server that blindly serves script output from git.

While the solution here is quite automated, it is not particularly flexible.  Simplicity and executing a proof of concept were priorities in this exercise.

All development was done on an EC2 machine running FreeBSD 11.1-RELEASE.  It is configured as a jail host using ezjail and a secondary loopback device for network isolation.

In the interest of keeping the solution "pared down", I went with a handwritten microserver.  Since SSL was required, I opted for HTTP::Daemon::SSL, which downloads as a freebsd package under 6kB.

All of the building and configuring are performed by the Makefile.  There are three particularly relevant targets.  The default target, all, creates the jail and installs and configures the softwares.  Once executed, the server should be fully functional.  The test target creates a local git repository, syncs it upstream, and executes the web request.  When this target is executed, the web request results are displayed as output.  The clean target resets by eliminating the jail, the local repository, and cleaning up other loose files.

Some relevant settings follow.

## rc.conf:
```
ezjail_enable="YES"
cloned_interface="lo1"
pf_enable="YES"
gateway_enable="YES"
```
  
## pf.conf
```
#Declare the interfaces, Public IP, private subnet,
EXT_IF = "xn0"
INT_IF = "lo1"
  
# Allow outbound connections from within the jails
nat on $EXT_IF from $INT_IF:network to any -> ($EXT_IF)
  
# an example port redirect
rdr on $EXT_IF proto tcp from any to any port 80 -> $127.0.1.99 port 80
```
