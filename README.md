# Metasensor


# Demonstration videos

## Robot only

Here is a video of the behaviour of the robotic system alone, similar to Braitenber's "fear" vehicle, i.e. the one that avoids light.

- [Robot only](videos/robot-only.mp4)

## Hand-coded version of the metasensor

Here is a video demonstration of the metasensor-robot system in the case of a set of hand-coded rules governing the metasensor:

- [Hand-coded (Robot + Metasensor)](videos/hand-coded-metasensor.mp4)


## Automatically designed version of the metasensor

Here is the video of the best robot found by the genetic algorithm.

- [GA designed (Robot + Metasensor)](videos/ga-optmised-metasensor.mp4)


## Instructions for replicating experiments

Install NetLogo from: [https://ccl.northwestern.edu/netlogo/](https://ccl.northwestern.edu/netlogo/)

To launch the genetic algorithm run the following command:
```python
python3 ga.py [SEED] [NUM_GENERATIONS] [POPULATION_SIZE] [SIMULATION_STEPS]
```
After that, the best solution found with the genetic algorithm can be tested by setting its unique number in the netlogo application "metasensor.nlogo", via its GUI.
