CC ?= clang
CFLAGS ?= -std=c17 -Wall -Wextra -Werror -pedantic -O3 -pthread -I../../c_fastpath/include
LDFLAGS ?= -L../../c_fastpath/lib -lfastpath -lm -pthread

TARGET = ../../bin/test_fastpath

all: $(TARGET)

$(TARGET): test_fastpath.c
	mkdir -p ../../bin
	$(CC) $(CFLAGS) $< $(LDFLAGS) -o $@

test: $(TARGET)
	$(TARGET)

clean:
	rm -f $(TARGET)
