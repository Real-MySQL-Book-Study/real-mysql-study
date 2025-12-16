```bash
docker exec -i reservation-mysql mysql -uroot -proot1234 hospital < scripts/00-prepare-data.sql

docker exec -i reservation-mysql mysql -uroot -proot1234 hospital < data/generate_data.sql

docker exec -it reservation-mysql mysql -u hospital_user -p
```
