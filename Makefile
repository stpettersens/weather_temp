SRC = weather_temp.d
CFG_FILE = weather_temp.cfg
CFG_DIR = /etc
TARGET = weather_temp

rm=rm
exe=
o=.o

uname := $(shell uname)

# https://github.com/stpettersens/uname-windows
ifeq ($(uname),Windows)
	rm=del
	exe=.exe
	o=.obj
endif

make:
	ldc2 $(switches)$(SRC)
	$(rm) $(TARGET)$(o)
	strip $(TARGET)$(exe)
	./$(TARGET)$(exe)

compress:
	upx -9 $(TARGET)$(exe)

install:
	@echo "Please run as doas/sudo."
	cp $(TARGET) /usr/local/bin
	cp $(CFG_FILE) $(CFG_DIR)

clean:
	$(rm) $(TARGET)
