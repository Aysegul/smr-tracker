INCLUDE = -I. -I/usr/local/include
LDFLAGS := -lluajit -lluaT -lth
LIBOPTS = -shared
CFLAGS = -Ofast -mfpu=neon -fopenmp -c -fpic -Wall
CC = gcc


.PHONY : all
all : libsmrdist.so


smrdist.o :
	$(CC) $(CFLAGS) $(INCLUDE) smrdist.c


libsmrdist.so : smrdist.o
	$(CC) $< $(LIBOPTS) -o $@ $(LDFLAGS)



install : libsmrdist.so
	mkdir -p ${HOME}/.luarocks/lib/lua/5.1/
	cp libsmrdist.so ${HOME}/.luarocks/lib/lua/5.1/


.PHONY : clean
clean :
	rm -f *.o libsmrdist.so

