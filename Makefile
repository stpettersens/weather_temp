make:
	ldc2 weather_temp.d
	rm weather_temp.o
	upx -9 weather_temp
