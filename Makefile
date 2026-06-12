make:
	ldc2 weather_temp.d
	strip weather_temp

compress:
	upx -9 weather_temp
