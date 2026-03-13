This is a dockerized version of the [turtlebot3_drlnav](https://github.com/tomasvr/turtlebot3_drlnav) project, built to make getting the simulation up and running as straightforward as possible without having to manually deal with ROS installation, dependency conflicts, or environment setup.

The container ships with ROS 2 Foxy and Gazebo 11. Both have reached end-of-life status, but they remain functional for the purposes of this project. At some point in the future it would be worth migrating to a supported distribution, but that is out of scope for now.

An NVIDIA GPU is optional but recommended, particularly if you plan to run training. The container will work on CPU-only machines, just expect slower performance.

---

## Prerequisites

You will need the following installed on your machine before starting:

- [Docker](https://docs.docker.com/engine/install/)
- [Docker Compose](https://docs.docker.com/compose/install/) (comes bundled with Docker Desktop; on Linux install separately)
- (Optional) [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) — only needed if you want GPU passthrough

If you are on Linux and plan to use the Gazebo graphical interface, you also need to allow Docker to connect to your display. Run this once in your terminal before starting the container:

```bash
xhost +local:docker
```

This grants Docker containers permission to open windows on your screen. You will need to re-run this command each time you log in, or add it to your `~/.profile` to make it permanent:

```bash
echo "xhost +local:docker" >> ~/.profile
```

---

## Using on WSL2 (Windows)

WSL2 has a few differences from a native Linux setup that are worth knowing about before you start.

**Docker**

Install Docker Engine directly inside your WSL2 terminal, not Docker Desktop on Windows. Docker Desktop adds unnecessary overhead and can interfere with how the container handles networking and GPU passthrough. Run the following inside your WSL2 terminal to install Docker Engine:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

Then add your user to the docker group so you do not have to prefix every command with `sudo`:

```bash
sudo usermod -aG docker $USER
```

Close your WSL2 terminal and reopen it for the group change to take effect. Verify the installation worked:

```bash
docker run hello-world
```

You also need to start the Docker daemon manually each time you open a new WSL2 session, since WSL2 does not run systemd by default:

```bash
sudo service docker start
```

To avoid running this every time, add it to your `~/.bashrc`:

```bash
echo "sudo service docker start" >> ~/.bashrc
```

> If you are on a newer WSL2 setup with systemd enabled (you can check with `ps -p 1 -o comm=` — if it prints `systemd` you have it), you can enable Docker as a proper service instead and skip the above:
> ```bash
> sudo systemctl enable docker
> sudo systemctl start docker
> ```

**Display passthrough (getting Gazebo to open a window)**

On Windows 11, WSL2 ships with WSLg, which handles graphical applications automatically. You do not need to install anything extra or set a `DISPLAY` variable — Gazebo windows should just appear on your Windows desktop when launched from inside the container.

To check if WSLg is working, run this inside your WSL2 terminal before starting the container:

```bash
echo $DISPLAY
```

If it prints something like `:0` or a path starting with `/mnt/wslg/`, you are good to go.

On Windows 10, WSLg is not available. You will need to install a third-party X server on Windows to receive graphical output. [VcXsrv](https://sourceforge.net/projects/vcxsrv/) is free and works well. After installing and launching it (use the "Multiple windows" option and disable access control on the last screen), set the display variable in your WSL2 terminal:

```bash
export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0
```

Add that line to your `~/.bashrc` inside WSL2 to make it automatic:

```bash
echo "export DISPLAY=\$(cat /etc/resolv.conf | grep nameserver | awk '{print \$2}'):0" >> ~/.bashrc
```

The `xhost +local:docker` step from the Linux instructions is not needed on WSL2 — skip it.

**GPU passthrough**

For NVIDIA GPU passthrough on WSL2, the driver needs to be installed on the Windows side, not inside WSL2. Install the latest [NVIDIA driver for Windows](https://www.nvidia.com/Download/index.aspx) (a recent Game Ready or Studio driver is fine), then install the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) inside your WSL2 environment. Docker Desktop handles the rest.

Do not install a separate CUDA toolkit inside WSL2 — the Windows driver exposes CUDA through WSL2 automatically.

**Network mirroring and UDP multicast (required for ROS 2)**

By default, WSL2 uses NAT networking, which blocks UDP multicast. ROS 2 relies heavily on UDP multicast for node discovery — without it, `ros2 topic list` will hang, nodes will not see each other, and the simulation will not function properly.

You need to switch WSL2 to mirrored networking mode and open the Hyper-V firewall to allow inbound traffic. This requires two steps, both done on the Windows side.

First, create or edit the `.wslconfig` file in your Windows user folder. Open PowerShell (no admin needed for this step) and run:

```powershell
Add-Content "$env:USERPROFILE\.wslconfig" "`n[wsl2]`nnetworkingMode=mirrored`nhostAddressLoopback=true"
```

If you already have a `.wslconfig` file with a `[wsl2]` section, open it manually instead (`notepad $env:USERPROFILE\.wslconfig`) and add the two lines under the existing `[wsl2]` header so you do not end up with duplicates:

```ini
[wsl2]
networkingMode=mirrored
hostAddressLoopback=true
```

Second, open PowerShell as Administrator and run this command to allow inbound connections through the Hyper-V firewall:

```powershell
Set-NetFirewallHyperVVMSetting -Name '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' -DefaultInboundAction Allow
```

Then shut down WSL2 completely so the new config is picked up on next start:

```powershell
wsl --shutdown
```

Reopen your WSL2 terminal and verify mirrored mode is active:

```bash
wslinfo --networking-mode
```

It should print `mirrored`. After this, ROS 2 node discovery and UDP multicast will work correctly both inside the container and between WSL2 and other machines on your network.

> This requires Windows 11 22H2 or later. If you are on an older version, mirrored networking is not available and you will need to run ROS 2 with `ROS_LOCALHOST_ONLY=1` set, which limits communication to within the same machine only.

**Cloning the repo**

Clone the repository from inside your WSL2 terminal, not from Windows Explorer or PowerShell. Cloning into the Windows filesystem (anywhere under `/mnt/c/`) will cause serious performance problems and potential file permission issues with ROS. Always work inside the WSL2 filesystem:

```bash
cd ~
git clone https://github.com/abhinavpathak9873/bits_dynamic_navigation_sim.git
cd bits_dynamic_navigation_sim
```

Everything from the Getting Started section onwards is identical to Linux.

---

## Getting Started

Clone the repository and navigate into it:

```bash
git clone https://github.com/abhinavpathak9873/bits_dynamic_navigation_sim.git
cd bits_dynamic_navigation_sim
```

Build the Docker image. This will take a while the first time as it downloads ROS, Gazebo, PyTorch, and all other dependencies:

```bash
docker compose build
```

Start the container in the background:

```bash
docker compose up -d
```

Open a shell inside the container:

```bash
docker exec -it turtlebot3_drlnav bash
```

You should land directly in `/home/turtlebot3_drlnav`. You can confirm with:

```bash
pwd
```

---

## Building the Workspace

The first time you enter the container (and any time you modify source files), you need to build the ROS workspace:

```bash
colcon build
```

Once the build finishes, source the workspace so ROS can find the packages:

```bash
source /opt/ros/foxy/setup.bash
source install/setup.bash
```

> If you find yourself re-sourcing these every session, both lines are already present in `~/.bashrc` and will run automatically on each new shell. If they are not taking effect, try opening a fresh terminal in the container.

---

## Running the Simulation

To launch the Gazebo simulation environment:

```bash
ros2 launch turtlebot3_gazebo turtlebot3_drl_stage4.launch.py
```

There are four stages available, each representing a different map with increasing complexity:

```bash
ros2 launch turtlebot3_gazebo turtlebot3_drl_stage1.launch.py   # simplest
ros2 launch turtlebot3_gazebo turtlebot3_drl_stage2.launch.py
ros2 launch turtlebot3_gazebo turtlebot3_drl_stage3.launch.py
ros2 launch turtlebot3_gazebo turtlebot3_drl_stage4.launch.py   # most complex
```

If you just want to drive the robot around manually without any training, open a second terminal session in the container and run:

```bash
docker exec -it turtlebot3_drlnav bash
ros2 run turtlebot3_teleop teleop_keyboard
```

---

## Notes on the libGL Warnings

When launching Gazebo you may see output like:

```
libGL error: MESA-LOADER: failed to retrieve device information
libGL error: failed to load driver: i915
```

These are warnings, not errors. The simulation server (`gzserver`) runs fine regardless. The warnings appear because the Gazebo GUI client (`gzclient`) is trying to use hardware OpenGL acceleration through the Intel integrated GPU. If the Gazebo window opens but appears black, add the following line to the `environment` section of `docker-compose.yml` and restart the container:

```yaml
- LIBGL_ALWAYS_SOFTWARE=1
```

This switches to software rendering, which is slower but guaranteed to work on any machine.

---

## Stopping the Container

```bash
docker compose down
```

Your workspace files persist on your host machine inside the `turtlebot3_drlnav` folder, so nothing is lost when the container stops.