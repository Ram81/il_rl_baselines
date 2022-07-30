#!/bin/bash
#SBATCH --job-name=onav_il
#SBATCH --gres gpu:1
#SBATCH --nodes 1
#SBATCH --cpus-per-task 6
#SBATCH --ntasks-per-node 1
#SBATCH --signal=USR1@1000
#SBATCH --partition=short
#SBATCH --constraint=a40
#SBATCH --exclude=chappie,robby
#SBATCH --output=slurm_logs/ddpil-%j.out
#SBATCH --error=slurm_logs/ddpil-%j.err
#SBATCH --requeue

source /srv/flash1/rramrakhya6/miniconda3/etc/profile.d/conda.sh
conda deactivate
conda activate scene-graph

export GLOG_minloglevel=2
export MAGNUM_LOG=quiet

MASTER_ADDR=$(srun --ntasks=1 hostname 2>&1 | tail -n1)
export MASTER_ADDR

config=$1

DATA_PATH="data/datasets/objectnav/objectnav_hm3d/objectnav_hm3d_10k"
TENSORBOARD_DIR="tb/objectnav_scene_graph/overfitting/mask_rcnn_small/no_prev_action_bfix/seed_5_full/"
CHECKPOINT_DIR="data/new_checkpoints/objectnav_scene_graph/overfitting/mask_rcnn_small/no_prev_action_bfix/seed_5_full/"
INFLECTION_COEF=3.234951275740812
set -x

echo "In ObjectNav IL DDP"
srun python -u -m habitat_baselines.run \
--exp-config $config \
--run-type train \
TENSORBOARD_DIR $TENSORBOARD_DIR \
CHECKPOINT_FOLDER $CHECKPOINT_DIR \
CHECKPOINT_INTERVAL 100 \
NUM_UPDATES 5000 \
NUM_PROCESSES 4 \
LOG_INTERVAL 1 \
IL.BehaviorCloning.num_steps 64 \
IL.BehaviorCloning.num_mini_batch 2 \
TASK_CONFIG.TASK.INFLECTION_WEIGHT_SENSOR.INFLECTION_COEF $INFLECTION_COEF \
TASK_CONFIG.DATASET.SPLIT "sample" \
TASK_CONFIG.DATASET.DATA_PATH "$DATA_PATH/{split}/{split}.json.gz" \
TASK_CONFIG.DATASET.TYPE "ObjectNav-v2" \
TASK_CONFIG.DATASET.MAX_EPISODE_STEPS 700 \
TASK_CONFIG.TASK.SENSORS "['OBJECTGOAL_SENSOR', 'DEMONSTRATION_SENSOR', 'INFLECTION_WEIGHT_SENSOR']" \
MODEL.hm3d_goal True \
MODEL.USE_DETECTOR True \
MODEL.SPATIAL_ENCODER.gcn_type "local_gcn_encoder" \
MODEL.SPATIAL_ENCODER.no_node_cat True \
MODEL.SPATIAL_ENCODER.no_bbox_feats False \
MODEL.SPATIAL_ENCODER.filter_nodes False \
MODEL.SPATIAL_ENCODER.conv_layer "GCNConv" \
MODEL.SPATIAL_ENCODER.out_features_dim 512 \
MODEL.SPATIAL_ENCODER.no_gcn False \
MODEL.SPATIAL_ENCODER.ablate_gcn False \
MODEL.USE_SEMANTICS False \
MODEL.USE_PRED_SEMANTICS False \
MODEL.SEMANTIC_ENCODER.is_hm3d False \
MODEL.SEMANTIC_ENCODER.is_thda False \
MODEL.SEQ2SEQ.use_prev_action False \
MODEL.DETECTOR.config_path "configs/detector/mask_rcnn/mask_rcnn_r50_150k_256x256.py" \
MODEL.DETECTOR.checkpoint_path "data/new_checkpoints/mmdet/detector/mask_rcnn_r50_1496cat_150k_ds_256x256.pth"
# MODEL.RGB_ENCODER.cnn_type "ResnetRGBEncoder" \
# MODEL.DEPTH_ENCODER.cnn_type "VlnResnetDepthEncoder"

