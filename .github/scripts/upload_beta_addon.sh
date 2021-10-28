#!/bin/bash -e

# This script uploads beta version of LotI (current master branch) to the Wesnoth addon server.
# It is called automatically by GitHub Actions (see .github/workflows/main.yml).

ADDON=Legend_of_the_Invincibles_beta

[ -f wesnoth_tools/COMPLETE ] || (
	# Download Wesnoth core (contains WML linter utility and its dependencies).
	# These tools are saved in the cache (to not download the entire Wesnoth next time).
	git clone -q --depth 1 https://github.com/wesnoth/wesnoth
	rm -rf wesnoth_tools
	mv wesnoth/data/tools wesnoth_tools

	touch wesnoth_tools/COMPLETE
)

if [ "$PBL_PASSPHRASE" = "" ] || [ $PBL_EMAIL = "" ]; then
	echo "Either PBL_PASSPHRASE or PBL_EMAIL is not specified in the environment. Exiting."
	exit 0
fi

rsync --exclude .git --exclude wesnoth_tools -a . $ADDON
find $ADDON -type f | xargs sed -i "s@add-ons/Legend_of_the_Invincibles@add-ons/$ADDON@g"

for WESNOTH_VERSION in "1.14.x"; do
	python wesnoth_tools/wesnoth_addon_manager \
		-u $ADDON \
		--port $WESNOTH_VERSION \
		--pbl $ADDON/beta.pbl \
		--pbl-key passphrase $PBL_PASSPHRASE \
		--pbl-key email $PBL_EMAIL \
		--pbl-key version $(git describe HEAD --tags | tr '-' '.')
done
