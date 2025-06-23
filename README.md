# 🗃️ BDTurnero - Base de Datos MySQL  
## ▶️ **Cómo usarlo**  
```bash
git clone https://github.com/Lauuti19/BDTurnero.git
cd BDTurnero

# Crear red (si no existe)
docker network create turnero-network

# Iniciar MySQL
docker-compose up -d

## 🔄 **Relación con Otros Componentes**  
Esta base de datos es **requerida por**:  
- **[BackTurnero](https://github.com/Lauuti19/BackTurnero)** - API que usa MySQL para almacenar datos.  

📌 **Flujo recomendado**:  
1. Clona y ejecuta **este repositorio primero** (BD).  
2. Luego inicia [BackTurnero](https://github.com/Lauuti19/BackTurnero).  
3. Finalmente, levanta [FrontTurnero](https://github.com/Lauuti19/FrontTurnero).  

⚠️ **Nota**:  
- Sin esta BD, el backend **no funcionará**.  
- REcuerda usa `turnero-network` en Docker para conexión automática.  
