#!/bin/bash
#SBATCH --job-name=onav_ilrl
#SBATCH --gres gpu:4
#SBATCH --nodes 1
#SBATCH --cpus-per-task 6
#SBATCH --ntasks-per-node 4
#SBATCH --signal=USR1@300
#SBATCH --partition=short
#SBATCH --constraint=a40
#SBATCH --exclude=conroy
#SBATCH --output=slurm_logs/ddp-il-rl-%j.out
#SBATCH --error=slurm_logs/ddp-il-rl-%j.err
#SBATCH --requeue

source /srv/flash1/rramrakhya6/miniconda3/etc/profile.d/conda.sh
conda deactivate
conda activate il-rl

export GLOG_minloglevel=2
export MAGNUM_LOG=quiet

MASTER_ADDR=$(srun --ntasks=1 hostname 2>&1 | tail -n1)
export MASTER_ADDR

config="habitat_baselines/config/objectnav/il_rl/ddppo_semseg_ft_objectnav.yaml"

TENSORBOARD_DIR="tb/objectnav_il_rl_ft/ddppo_hm3d_pt_s_path_240k/sem_seg_pred/sparse_reward_pt_ckpt_16_no_schedule/hm3d_v0_1_0/seed_1/"
CHECKPOINT_DIR="data/new_checkpoints/objectnav_il_rl_ft/ddppo_hm3d_pt_s_path_240k/sem_seg_pred/sparse_reward_pt_ckpt_16_no_schedule/hm3d_v0_1_0/seed_1/"
DATA_PATH="data/datasets/objectnav/objectnav_hm3d/objectnav_hm3d_v1/"
PRETRAINED_WEIGHTS="data/new_checkpoints/objectnav_il/objectnav_hm3d/objectnav_hm3d_s_path_240k/sem_seg_pred/seed_1/ckpt.16.pth"
set -x

echo "In ObjectNav IL+RL DDP"
srun python -u -m habitat_baselines.run \
--exp-config $config \
--run-type train \
SENSORS "['RGB_SENSOR', 'DEPTH_SENSOR', 'SEMANTIC_SENSOR']" \
TENSORBOARD_DIR $TENSORBOARD_DIR \
CHECKPOINT_FOLDER $CHECKPOINT_DIR \
NUM_UPDATES 20000 \
RL.DDPPO.pretrained_weights $PRETRAINED_WEIGHTS \
RL.DDPPO.distrib_backend "NCCL" \
RL.Finetune.start_actor_finetuning_at 0 \
RL.Finetune.actor_lr_warmup_update 0 \
RL.Finetune.start_critic_warmup_at 0 \
RL.Finetune.critic_lr_decay_update 0 \
RL.Finetune.policy_ft_lr 2.5e-4 \
RL.PPO.use_linear_lr_decay False \
RL.Finetune.finetune False \
TASK_CONFIG.DATASET.SPLIT "train" \
TASK_CONFIG.DATASET.DATA_PATH "$DATA_PATH/{split}/{split}.json.gz" \
TASK_CONFIG.TASK.SUCCESS.SUCCESS_DISTANCE 0.1 \
MODEL.hm3d_goal True \
MODEL.embed_sge True \
MODEL.USE_SEMANTICS True \
MODEL.USE_PRED_SEMANTICS True \
MODEL.SEMANTIC_ENCODER.is_hm3d False \
MODEL.SEMANTIC_ENCODER.is_thda True \
MODEL.SEMANTIC_PREDICTOR.name "rednet" \
