
# location of the hexloadr program
mem = 0xFF00

# location of the USR(x) jump address from RC2014 Basic SBC Searle
# usr = 0x8045+0x0003 
# location of the USR(x) jump address from RC2014 Basic ACIA feilipu
usr = 0x8120+0x0003
# location of the USR(x) jump address from YAZ180 Basic
#usr = 0x8000+0x0003

# fill the USR(x) jump with the address - adjust jump address too
print "doke "+str(usr-65536+1) + "," + str(mem) + "\r\n\r"

# now fill the RAM with the program bytes
with open("HEXLOADR.BIN", "rb") as f:
    byte = f.read(1)
    while byte != "":
        print "poke "+str( mem-65536 )+","+str( ord(byte) ) + "\r"
        mem = mem+1
        byte = f.read(1)

# now start the hexloadr program automatically
print "\r\nprint usr(0)\r"
