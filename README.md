# Nexus-with-Docker-Multiple-Instance
	sudo apt-get update && sudo apt-get install dos2unix
# REMOVED PROXY INJECTION - Safe to run without proxy
	git clone https://github.com/R1ghTsS/Nexus-with-Docker-Proxy.git && cd Nexus-with-Docker-Proxy

Install nexus_setup

	dos2unix nexus_setup.sh && ./nexus_setup.sh

NOTE: If working (mining) fine, ctrl P + Q to exit

To run the 2nd instance, 3rd instance ...

	./nexus_setup.sh
