PERLDIR="/usr/local/lib64/perl5/"
TARGET="TimDB.pm"

install:
	mkdir -p ${PERLDIR}; \
	cp ${TARGET} ${PERLDIR}
