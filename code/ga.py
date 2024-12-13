import random
from deap import base, creator, tools, algorithms
import os
import xml.etree.ElementTree as ET
import subprocess
import pandas as pd
import multiprocessing
import numpy as np
import hashlib
import shutil
import matplotlib.pyplot as plt
import sys
import platform
import logging
from datetime import datetime

class MyGenotype(list):
    def __init__(self, input_size=None, hidden_size=None, output_size=None, values=None):
        if values is not None:
            super().__init__(values)
        else:
            super().__init__(self.initialize_genotype(input_size, hidden_size, output_size))
        self.unique_id = self.generate_unique_id()

    def initialize_genotype(self, input_size, hidden_size, output_size):
        weights_input_to_hidden = np.random.uniform(-0.5, 0.5, input_size * hidden_size).tolist()
        weights_hidden_to_output = np.random.uniform(-0.5, 0.5, hidden_size * output_size).tolist()
        weights_bias_to_hidden = np.random.uniform(-0.5, 0.5, hidden_size).tolist()
        weights_bias_to_output = np.random.uniform(-0.5, 0.5, output_size).tolist()
        return weights_input_to_hidden + weights_hidden_to_output + weights_bias_to_hidden + weights_bias_to_output

    def generate_unique_id(self):
        str_values = ''.join(map(str, self))
        hash_object = hashlib.md5(str_values.encode())
        hash_part = hash_object.hexdigest()
        time_part = datetime.now().strftime("%H%M%S")
        unique_id = f"{hash_part}{time_part}{id(self)}"
        return unique_id

    def get_unique_id(self):
        return self.unique_id
    
    def __setitem__(self, key, value):
        super().__setitem__(key, value)
        self.unique_id = self.generate_unique_id()

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

system = platform.system()

if system == "Linux":
    netlogo_path = "/home/mbraccini/Documents/NetLogo-6.4.0-64/netlogo-headless.sh"
elif system == "Darwin":
    netlogo_path = "/Users/mbraccini/Documents/NetLogo\ 6.4.0/netlogo-headless.sh"
else:
    raise OSError("Unsupported operating system")

SIMULATION_STEPS_OFFLINE_OPTIMIZATION = int(sys.argv[4])

use_multiprocessing = False

input_size = 4
hidden_size = 5
output_size = 2

def safe_rmtree(folder_path):
    try:
        if os.path.exists(folder_path):
            shutil.rmtree(folder_path)
    except Exception as e:
        logging.error(f"Error removing {folder_path}: {e}")

def setup_experiment_file(filename, individualID, output_folder):
    root = ET.Element("experiments")
    experiment = ET.SubElement(root, "experiment")
    experiment.set("name", "experiment1")
    experiment.set("repetitions", "1")
    setup = ET.SubElement(experiment, "setup")
    setup.text = "setup"
    go = ET.SubElement(experiment, "go")
    go.text = "go"
    metasensor= ET.SubElement(experiment, "enumeratedValueSet")
    metasensor.set("variable", "metasensor?")
    metasensor = ET.SubElement(metasensor, "value")
    metasensor.set("value", "true")
    hand_coded = ET.SubElement(experiment, "enumeratedValueSet")
    hand_coded.set("variable", "hand-coded?")
    hand_coded = ET.SubElement(hand_coded, "value")
    hand_coded.set("value", "false")
    online_adaptation = ET.SubElement(experiment, "enumeratedValueSet")
    online_adaptation.set("variable", "online-adaptation?")
    online_adaptation = ET.SubElement(online_adaptation, "value")
    online_adaptation.set("value", "false")
    experiment_folder = ET.SubElement(experiment, "enumeratedValueSet")
    experiment_folder.set("variable", "experiment-folder")
    experiment_folder = ET.SubElement(experiment_folder, "value")
    experiment_folder.set("value", output_folder)
    offline_optimization = ET.SubElement(experiment, "enumeratedValueSet")
    offline_optimization.set("variable", "offline-optimization?")
    offline_optimization = ET.SubElement(offline_optimization, "value")
    offline_optimization.set("value", "true")
    offline_solution_id = ET.SubElement(experiment, "enumeratedValueSet")
    offline_solution_id.set("variable", "offline-solution-id")
    offline_solution_id = ET.SubElement(offline_solution_id, "value")
    offline_solution_id.set("value", str(individualID))
    simulation_steps_offline_optimization = ET.SubElement(experiment, "enumeratedValueSet")
    simulation_steps_offline_optimization.set("variable", "SIMULATION_STEPS_OFFLINE_OPTIMIZATION")
    simulation_steps_offline_optimization = ET.SubElement(simulation_steps_offline_optimization, "value")
    simulation_steps_offline_optimization.set("value", str(SIMULATION_STEPS_OFFLINE_OPTIMIZATION))
    tree = ET.ElementTree(root)
    with open(filename, "wb") as f:
        tree.write(f, encoding='utf-8', xml_declaration=False)
    with open(filename, 'r') as file:
        data = file.read()
    start_tag = '<enumeratedValueSet variable="offline-solution-id"><value value='
    end_tag = ' /></enumeratedValueSet>'
    start_index = data.find(start_tag) + len(start_tag)
    end_index = data.find(end_tag, start_index)
    current_value = data[start_index:end_index]
    if not (current_value.startswith("'") and current_value.endswith("'")):
        new_value = f"'{current_value}'"
        data = data[:start_index] + new_value + data[end_index:]
    with open(filename, 'w') as file:
        file.write(data)    
        
def run_experiment(filename):
    command = f"{netlogo_path} --model metasensor.nlogo --setup-file {filename}"
    subprocess.run(command, shell=True, check=True, text=True, capture_output=True)
      
def fitness_function(individual, output_folder):
    individual_ID = individual.get_unique_id()
    individual_folder = os.path.join(output_folder, str(individual_ID))
    if not os.path.exists(individual_folder):
        os.makedirs(individual_folder)
    xml_file = f"{individual_folder}/{str(individual_ID)}.xml"
    setup_experiment_file(xml_file,individual_ID, output_folder)
    individual_file = f"{individual_folder}/{str(individual_ID)}.txt"
    with open(individual_file, "w") as f:
        for item in individual:
            f.write(f"{item:.10f}\n")
    run_experiment(xml_file)
    results_file = f"{individual_folder}/{str(individual_ID)}.csv"
    results = pd.read_csv(results_file)
    fitness = results["fitness"].mean()
    folder_path = os.path.join(output_folder, str(individual_ID))
    safe_rmtree(folder_path)
    return fitness,

def performance_over_time(logbook, index_of_fitness, folder):
    mins = logbook.select("min")
    maxs = logbook.select("max")
    avgs = logbook.select("avg")
    plt.plot(logbook.select("gen"), mins, "b-", label="Minimum Fitness")
    plt.plot(logbook.select("gen"), maxs, "r-", label="Maximum Fitness")
    plt.plot(logbook.select("gen"), avgs, "g-", label="Average Fitness")
    plt.xlabel("Generation")
    plt.ylabel(f"Fitness")
    plt.legend(bbox_to_anchor=(1.04, 0.5), loc="center left", borderaxespad=0)
    plt.title(f"Fitness over Generations")
    plot_filename = os.path.join(folder, f"fitness_{index_of_fitness}_over_generations_SEED_{SEED}.png")
    plt.savefig(plot_filename,bbox_inches="tight")
    plt.close()

if __name__ == '__main__':
    SEED = int(sys.argv[1])
    output_folder =  str(SEED)
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)     
    random.seed(SEED)
    cxpb = 0.6
    mutpb = 0.4
    ngen = int(sys.argv[2])
    population_size = int(sys.argv[3])
    mu = int(population_size/4)
    lambda_ = population_size
    creator.create("FitnessMax", base.Fitness, weights=(1.0,))
    creator.create("Individual", MyGenotype, fitness=creator.FitnessMax)
    hof = tools.HallOfFame(1, similar=np.array_equal)
    toolbox = base.Toolbox()
    toolbox.register("individual", creator.Individual, input_size, hidden_size, output_size)
    toolbox.register("population", tools.initRepeat, list, toolbox.individual)
    toolbox.register("evaluate", fitness_function, output_folder=output_folder)
    toolbox.register("select", tools.selTournament, tournsize=3)
    toolbox.register("mate", tools.cxTwoPoint)
    toolbox.register("mutate", tools.mutGaussian, mu=0, sigma=1, indpb=0.2)
    population = toolbox.population(n=population_size)
    stats = tools.Statistics(lambda ind: ind.fitness.values)
    stats.register("avg", np.mean)
    stats.register("std", np.std)
    stats.register("min", np.min)
    stats.register("max", np.max)
    if use_multiprocessing:
        num_cores = multiprocessing.cpu_count()
        pool = multiprocessing.Pool(processes=int(num_cores - 1))
        toolbox.register("map", pool.map)
    population, logbook = algorithms.eaMuPlusLambda(population, toolbox, mu, lambda_, cxpb, mutpb, ngen, stats=stats, halloffame=hof, verbose=True)
    if use_multiprocessing:
        pool.close()
        pool.join()
    stats_file = os.path.join(output_folder, f"stats_SEED_{SEED}.csv")
    pd.DataFrame(logbook).to_csv(stats_file, index=False)
    for ind in hof:
        ind.fitness.values = toolbox.evaluate(ind)
    
    best_individual = hof[0]
    best_fitness = best_individual.fitness.values[0]    
    best_unique_ID = best_individual.get_unique_id()
    best_folder = os.path.join(output_folder, str(best_unique_ID))
    if not os.path.exists(best_folder):
        os.makedirs(best_folder)
    best_weigths_file = os.path.join(best_folder, f"{str(best_unique_ID)}.txt")
    with open(best_weigths_file, "w") as f:
        for item in best_individual:
            f.write(f"{item:.10f}\n")
    individual_folder = os.path.join(output_folder, str(best_unique_ID))
    xml_file = f"{individual_folder}/{str(best_unique_ID)}.xml"
    setup_experiment_file(xml_file,best_unique_ID, output_folder)
    run_experiment(f"{individual_folder}/{str(best_unique_ID)}.xml")
    performance_over_time(logbook, 0, output_folder)
    best_fitness_file = os.path.join(output_folder, f"best_fitness_SEED_{SEED}.csv")
    best_fitness = pd.DataFrame({"LAST":[tools.selBest(population, 1)[0].fitness.values[0]], "HOF":[hof[0].fitness.values[0]]})
    best_fitness.to_csv(best_fitness_file, index=False)
