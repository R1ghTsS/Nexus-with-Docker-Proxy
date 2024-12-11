# Nexus-with-Docker-Proxy

``sudo apt update && sudo apt install curl wget && sudo apt install dos2unix``

``wget -O nexus_setup.sh https://raw.githubusercontent.com/R1ghTsS/Nexus-with-Docker-Proxy/main/nexus_setup.sh``

``nano nexus_setup.sh``

	edit Prover ID with yours on this part
		# Set up Nexus Prover ID
		RUN mkdir -p /root/.nexus && echo "PROVER ID (do not remove qoutes)" > /root/.nexus/prover-id
To Exit CTRL + X + Y + Enter

	chmod +x nexus_setup.sh

	dos2unix nexus_setup.sh

	./nexus_setup.sh

NOTE: If working (mining) fine, ctrl P + Q to exit

To run the 2nd instance

	./nexus_setup.sh
