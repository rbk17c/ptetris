import time
from machine import I2C, Pin


def main():
 led_machine = 1

 i2c = machine.I2C(0, freq=3000, timeout=1000000)
 led = Pin('LED', Pin.OUT)
 #led.value(led_machine)
 b=bytearray([0x74,0x11,0xe,0xde,0xe0,0xc9,0x79,0x0,0xf3,0xb,0xc0,0xe2,0xab,0xc0,0x68,0x7b])




 err=Transmit(i2c, addr, b)

 return 0

 
 while True:
  for i in range (1,9):
   z=(1<<i)-1
   print("hello there...", z)
   try:
#            i2c.writeto(0x55, q, stop=True)
    b[0]=bytes([z])
    buf = i2c.writeto(0x21, b, True)
    if led_machine>0:
     led_machine = 0 #(led_machine & 1 ) ^ 1
    else:
     led_machine = 1
   except Exception as e:
     print ("i2c error",e)
     led_machine=3
   print (led_machine)    
   if led_machine == 3:
    for _ in range(10):
     led.toggle()
     time.sleep(.1)
   else:            
    led.value(led_machine)
    time.sleep(.5)

def Transmit(i2c, addr, b):
  return 0

main()
