// =====================================================================
// S05: Consultas con MongoDB
// Base de datos: ita-da-s05 (colecciones: users, theaters, sessions,
// movies, comments)
// Las consultas se lanzan desde la shell de MongoDB Compass (MONGOSH).
// =====================================================================

use("ita-da-s05");

// =====================================================================
// NIVEL 1
// =====================================================================

// --- Ejercicio 1.1: Los 2 primeros comentarios ---------------------------
// Los dos primeros por orden de la coleccion.
db["comments"].find().limit(2);

// Los dos mas antiguos segun la fecha del comentario.
db["comments"].find().sort("date").limit(2);


// --- Ejercicio 1.2: Usuarios registrados -----------------------------------
db["users"].countDocuments();


// --- Ejercicio 1.3: Cines en California -----------------------------------
db["theaters"].countDocuments({"location.address.state":"CA"});


// --- Ejercicio 1.4: Primer usuario en registrarse ------------------------
// users no tiene fecha de alta, asi que ordeno por _id (ObjectId), que
// lleva la fecha de creacion incrustada, de menor a mayor.
db["users"].find().sort({"_id":1}).limit(1);


// --- Ejercicio 1.5: Peliculas de comedia ----------------------------------
// movies tambien guarda series (type "series"), asi que filtro por
// type "movie" en todas las consultas que piden peliculas.
db["movies"].countDocuments({"genres":"Comedy","type":"movie"});


// --- Ejercicio 2: Peliculas de 1932, drama o en frances -------------------
db["movies"].countDocuments({type:"movie",year:1932,"$or":[{genres:"Drama"},{languages:"French"}]});

db["movies"].find({type:"movie",year:1932,"$or":[{genres:"Drama"},{languages:"French"}]});


// --- Ejercicio 3: Peliculas de EE. UU., 5-9 premios, 2012-2014 -----------
db["movies"].countDocuments({
    type:"movie",
    countries:"USA",
    year:{"$gte":2012,"$lte":2014},
    "awards.wins":{"$gte":5,"$lte":9}
});

db["movies"].find({
    type:"movie",
    countries:"USA",
    year:{"$gte":2012,"$lte":2014},
    "awards.wins":{"$gte":5,"$lte":9}
});

// Valores de year que no son numericos (por ejemplo "2012-" en series).
// El filtro numerico de arriba no los recoge.
db.movies.distinct(
    "year",
    {year: {$not: {$type: "number"}}}
);


// =====================================================================
// NIVEL 2
// =====================================================================

// --- Ejercicio 1: Comentarios de usuarios con dominio GAMEOFTHRON.ES ----
// Comparacion sin distinguir mayusculas y anclada al final del email.
db["comments"].countDocuments({
    email:{$regex:"@GAMEOFTHRON\\.ES$",$options:"i"}
});


// --- Ejercicio 2: Cines por codigo postal en Washington D. C. -------------
db["theaters"].aggregate([
    {"$match":{"location.address.state":"DC"}},
    {"$group":{_id:"$location.address.zipcode",
               "theaters":{"$sum":1}}},
    {"$sort":{"theaters":1}}
]);


// =====================================================================
// NIVEL 3
// =====================================================================

// --- Ejercicio 1: Peliculas de John Landis con IMDb entre 7,5 y 8 -------
db["movies"].countDocuments({
    "type":"movie",
    "directors":"John Landis",
    "imdb.rating":{"$gte":7.5,"$lte":8}
});

db["movies"].find({
    "type":"movie",
    "directors":"John Landis",
    "imdb.rating":{"$gte":7.5,"$lte":8}
});


// --- Ejercicio 2: Mapa con la ubicacion de todos los cines ---------------
// No lleva script. Se hace en Compass: theaters > pestaña Schema >
// analizar el campo location.geo, que muestra el mapa con los puntos.
// El informe de Schema se basa en una muestra de 1000 documentos como
// maximo y theaters tiene 1564 cines, asi que se analiza en dos partes
// con estos filtros en la barra de consulta de Schema:
//   {"location.address.state": {"$lt": "M"}}   (628 cines)
//   {"location.address.state": {"$gte": "M"}}  (936 cines)
