import pandas as pd
from handle_sensors_module import *
import numpy as np

import os 
files_in_dir = os.listdir()
files_txt = [i for i in files_in_dir if i.endswith('.txt')]

for file_name in files_txt:
    with open(f"{file_name}", 'r') as file:
        if not file.readline():
            continue
        
        dados_com_n = file.readlines()
        dados_ = [dado.rstrip() for dado in dados_com_n]

        list_of_dicts = []

        contador = 0

        for data in dados_:
            try:
                if data[0:4] == "5551" and data[22:26] == "5552" and data[44:48] == "5553" and data[66:70] == "5554":
                    acel_x, acel_y, acel_z, temp = handleSensor1(data[0:22])
                    vel_x, vel_y, vel_z = handleSensor2(data[22:44])
                    roll, pitch, yall = handleSensor3(data[44:66])
                    mag_x, mag_y, mag_z = handleSensor4(data[66:88])
                    air_press, altitude = handleSensor5(data[88:110])
                    longitude, latitude = handleSensor6(data[110:132])
                    velocidade_gps = handleSensor7(data[132:154])
                    angle = data[191:(data.find('#'))]
                    horario = data[176:191]
                    rpm = data[data.find('#') + 1:data.find('$')]
                    vel = data[data.find('$') + 1:data.find('!')]
                    brake_temp = data[data.find('!') + 1:data.find('@')]
                    pressao_freio = data[data.find('~') + 1:]

                    if angle[0] == 'A':
                        print(data)
                        continue

                    dict_data = {
                        "Aceleracao X": acel_x,
                        "Aceleracao Y": acel_y,
                        "Aceleracao Z": acel_z,
                        "Temperatura": temp,
                        "Velocidade X": vel_x,
                        "Velocidade Y": vel_y,
                        "Velocidade Z": vel_z,
                        "Roll": roll,
                        "Pitch": pitch,
                        "Yall": yall,
                        "Magnetico X": mag_x,
                        "Magnetico Y": mag_y,
                        "Magnetico Z": mag_z,
                        "Pressao do Ar": air_press,
                        "Altitude": altitude,
                        "Longitude": longitude,
                        "Latitude": latitude,
                        "Velocidade GPS": velocidade_gps,
                        "Angulo": angle,
                        "Horario": horario,
                        "RPM": rpm,
                        "Velocidade Hall": vel,
                        "Temperatura Disco": brake_temp,
                        "Pressao Freio": pressao_freio
                    }
                    list_of_dicts.append(dict_data)
                    contador += 1
            except Exception as e:
                print(f"Erro: {e}.\n\nPosicao: {contador} ")


        df = pd.DataFrame(data=list_of_dicts)

        MAX = 120

        # Vout = 0.05 x Pin+0.376
        # Pin = (Vout - 0.376) / 0.05

        df = df.iloc[20:]
        brake_voltage = df["Pressao Freio"].to_numpy().astype(float)
        df["Pressao Freio"] = np.abs((brake_voltage - 0.376) / 0.05)

        n = [i for i in range(len(df["Pressao Freio"]))]

        velocidade_raw = df["Velocidade Hall"].to_numpy().astype(float)

        velocidade_masked = np.where(
            velocidade_raw > MAX,
            np.nan,
            velocidade_raw
        )

        velocidade_interp = pd.Series(velocidade_masked).interpolate().fillna(
            method='bfill').fillna(method='ffill').to_numpy()

        df.to_csv(f'{file_name.replace(".txt","")}.csv', index=False)

        file.close()

        print(f"{file_name} finalizado.")
