CC ?= clang
CFLAGS ?= -std=c17 -Wall -Wextra -Werror -pedantic -O3 -pthread -Iinclude
LDFLAGS ?= -lm -pthread

BUILD_DIR = build
BIN_DIR = ../bin
LIB_DIR = lib

SRCS = src/fastpath_interf.c \
       src/fastpath_kinematics.c \
       src/fastpath_servo.c \
       src/fastpath_ipc.c

OBJS = $(SRCS:src/%.c=$(BUILD_DIR)/%.o)
MAIN_OBJ = $(BUILD_DIR)/fastpath_main.o

STATIC_LIB = $(LIB_DIR)/libfastpath.a
TARGET = $(BIN_DIR)/pellicle_fastpath_daemon

.PHONY: all clean

all: $(STATIC_LIB) $(TARGET)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(LIB_DIR):
	mkdir -p $(LIB_DIR)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(BUILD_DIR)/%.o: src/%.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(STATIC_LIB): $(OBJS) | $(LIB_DIR)
	ar rcs $@ $(OBJS)

$(TARGET): $(MAIN_OBJ) $(STATIC_LIB) | $(BIN_DIR)
	$(CC) $(CFLAGS) $< -L$(LIB_DIR) -lfastpath $(LDFLAGS) -o $@

clean:
	rm -rf $(BUILD_DIR) $(LIB_DIR) $(TARGET)
