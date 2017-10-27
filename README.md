# TimeSharing

En el shell de erlang:

1. c(p2).
2. p2:start().

Ahi deberían ver el programa funcionar, sería bueno si hacen pruebas para ver que tal. Nada más agreguen intrucciones a los programas en la lista de instrucciones de cada uno. 

Faltan básicamente 3 cosas por si quieren ir intentando mientras no estoy:
	a. hacer la función que lea el archivo linea por linea y lo pase al formato que estoy usando. Lo pueden ver en la ultima          función del archivo (start()). Ahí hay 3 spawns, cada uno inicia un pograma cuyo argumento es una lista con las                intrucciones. (Esto me ayudaría bastante)
	b. compartir las variables entre los procesos (programas) para que sean "globales".
  c. implementar la ejecución de instrucciones tomando en cuenta el tiempo que tarda cada una y el quantum disponible.
  
Cualquier cosa me preguntan :D
