FROM nvidia/cuda:11.3.1-base-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /home

RUN apt-get update && apt-get install -y --no-install-recommends \
        tzdata \
    && echo 'Etc/UTC' > /etc/timezone \
    && ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && rm -rf /var/lib/apt/lists/*


RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        wget \
        gnupg2 \
        lsb-release \
        software-properties-common \
        ca-certificates \
        locales \
        nano \
        tmux \
        git \
    && rm -rf /var/lib/apt/lists/*


RUN locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8

RUN add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
        python3.8 \
        python3.8-dev \
        python3-pip \
        python3-tk \
        python3-argcomplete \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 1 \
    && rm -rf /var/lib/apt/lists/*


RUN pip3 install --upgrade pip

RUN pip3 install \
        numpy==1.24.3 \
        matplotlib==3.7.1 \
        pandas==2.0.2 \
        pyqtgraph==0.12.4 \
        PyQt5==5.14.1

RUN pip3 install \
        torch==1.10.0+cu113 \
        torchvision==0.11.1+cu113 \
        torchaudio==0.10.0+cu113 \
        -f https://download.pytorch.org/whl/cu113/torch_stable.html


RUN curl -sSL https://packages.osrfoundation.org/gazebo.gpg \
        -o /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] \
        http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" \
        | tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null \
    && apt-get update && apt-get install -y --no-install-recommends \
        gazebo11 \
        libgazebo11-dev \
    && rm -rf /var/lib/apt/lists/*

ENV GAZEBO_MODEL_DATABASE_URI=""
RUN mkdir -p /root/.gazebo/models/ground_plane /root/.gazebo/models/sun

RUN wget -q https://raw.githubusercontent.com/osrf/gazebo_models/master/ground_plane/model.sdf \
        -O /root/.gazebo/models/ground_plane/model.sdf \
    && wget -q https://raw.githubusercontent.com/osrf/gazebo_models/master/ground_plane/model.config \
        -O /root/.gazebo/models/ground_plane/model.config \
    && wget -q https://raw.githubusercontent.com/osrf/gazebo_models/master/sun/model.sdf \
        -O /root/.gazebo/models/sun/model.sdf \
    && wget -q https://raw.githubusercontent.com/osrf/gazebo_models/master/sun/model.config \
        -O /root/.gazebo/models/sun/model.config


RUN add-apt-repository universe \
    && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
        http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" \
        | tee /etc/apt/sources.list.d/ros2.list > /dev/null \
    && apt-get update && apt-get install -y --no-install-recommends \
        ros-foxy-ros-base \
        ros-foxy-turtlebot3-description \
        ros-foxy-gazebo-ros-pkgs \
        ros-dev-tools \
        python3-rosdep \
    && rm -rf /var/lib/apt/lists/*


RUN rosdep init && rosdep update
WORKDIR /home/turtlebot3_drlnav

RUN echo '\n\
# ── ROS 2 Foxy ──────────────────────────────\n\
source /opt/ros/foxy/setup.bash\n\
\n\
# ROS2 domain id (machines with the same ID share messages)\n\
export ROS_DOMAIN_ID=1\n\
\n\
export DRLNAV_BASE_PATH="/home/turtlebot3_drlnav"\n\
\n\
# Source the workspace (safe no-op if not yet built)\n\
[ -f "$DRLNAV_BASE_PATH/install/setup.bash" ] && source "$DRLNAV_BASE_PATH/install/setup.bash"\n\
\n\
# Allow Gazebo to find TurtleBot3 models\n\
export GAZEBO_MODEL_PATH=$GAZEBO_MODEL_PATH:$DRLNAV_BASE_PATH/src/turtlebot3_simulations/turtlebot3_gazebo/models\n\
\n\
# Select TurtleBot3 model (burger | waffle | waffle_pi)\n\
export TURTLEBOT3_MODEL=burger\n\
\n\
# Allow Gazebo to find the obstacle-plugin\n\
export GAZEBO_PLUGIN_PATH=$GAZEBO_PLUGIN_PATH:$DRLNAV_BASE_PATH/src/turtlebot3_simulations/turtlebot3_gazebo/models/turtlebot3_drl_world/obstacle_plugin/lib\n\
' >> /root/.bashrc

ENV DEBIAN_FRONTEND=

CMD ["bash"]