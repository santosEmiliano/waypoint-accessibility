import app from './app.js';

const puerto = process.env.PORT || 3000;

// Express 5 pasa el error al callback si el puerto no está disponible
app.listen(puerto, (error) => {
  if (error) {
    console.error(`No se pudo iniciar el servidor en el puerto ${puerto}: ${error.message}`);
    process.exit(1);
  }
  console.log(`Servidor escuchando en http://localhost:${puerto}`);
});
