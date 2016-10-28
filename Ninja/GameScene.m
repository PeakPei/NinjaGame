//
//  GameScene.m
//  Ninja
//
//  Created by 雷馨 on 16/10/28.
//  Copyright (c) 2016年 雷馨. All rights reserved.
//

#import "GameScene.h"
#import "GameOverScene.h"

//创建一个私有的interface
@interface GameScene()

@property (nonatomic) SKSpriteNode *player;
@property (nonatomic) NSTimeInterval lastSpawnTimeInterval; //最近出现怪兽的时间
@property (nonatomic) NSTimeInterval lastUpdateTimeInterval; //上次更新的时间

@property (nonatomic) int monstersDestroyed;  //杀死怪兽30个游戏胜利

@end

static inline CGPoint rwAdd(CGPoint a, CGPoint b) {
    return CGPointMake(a.x + b.x, a.y + b.y);
}

static inline CGPoint rwSub(CGPoint a, CGPoint b) {
    return CGPointMake(a.x - b.x, a.y - b.y);
}

static inline CGPoint rwMult(CGPoint a, float b) {
    return CGPointMake(a.x * b, a.y * b);
}

static inline float rwLength(CGPoint a) {
    return sqrtf(a.x * a.x + a.y * a.y);
}

// Makes a vector have a length of 1
static inline CGPoint rwNormalize(CGPoint a) {
    float length = rwLength(a);
    return CGPointMake(a.x / length, a.y / length);
}

static const uint32_t projectileCategory     =  0x1 << 0;
static const uint32_t monsterCategory        =  0x1 << 1;

@implementation GameScene

- (id)initWithSize:(CGSize)size {
    if (self = [super initWithSize:size]) {
        //
        NSLog(@"size: %@", NSStringFromCGSize(size));
        //
        self.backgroundColor = [SKColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
        
        self.physicsWorld.gravity = CGVectorMake(0,0);
        self.physicsWorld.contactDelegate = self;
        
        //
        self.player = [SKSpriteNode spriteNodeWithImageNamed:@"player"];
        self.player.position = CGPointMake(self.player.size.width / 2, self.frame.size.height / 2);
        [self addChild:self.player];
    }
    return  self;
}

- (void)addMonster {
    //create sprite
    SKSpriteNode *monster = [SKSpriteNode spriteNodeWithImageNamed:@"monster"];
    
    //Determine where to spawn the monster along the Y axis
    int minY = monster.size.height / 2;
    int maxY = self.frame.size.height - monster.size.height / 2;
    int rangeY = maxY - minY;
    int actualY = (arc4random() % rangeY) + minY;
    
    //
    monster.position = CGPointMake(self.frame.size.width + monster.size.width / 2, actualY);
    [self addChild:monster];
    
    //Determine speed of the monster
    int minDuration = 2.0;
    int maxDuration = 4.0;
    int rangeDuration = maxDuration - minDuration;
    int actualDuration = (arc4random() % rangeDuration) + minDuration;
    
    //create the actions
    SKAction *actionMove = [SKAction moveTo:CGPointMake(-monster.size.width / 2, actualY) duration:actualDuration];
    SKAction *actionMoveDone = [SKAction removeFromParent];
//    [monster runAction:[SKAction sequence:@[actionMove, actionMoveDone]]];
    SKAction * loseAction = [SKAction runBlock:^{
        SKTransition *reveal = [SKTransition flipHorizontalWithDuration:0.5];
        SKScene * gameOverScene = [[GameOverScene alloc] initWithSize:self.size won:NO];
        [self.view presentScene:gameOverScene transition: reveal];
    }];
    [monster runAction:[SKAction sequence:@[actionMove, loseAction, actionMoveDone]]];
    
    //为怪兽创建一个对应的物体。此处，物体被定义为一个与怪兽相同尺寸的矩形(这样与怪兽形状比较接近)
    monster.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:monster.size]; // 1
    //将怪兽设置位dynamic。这意味着物理引擎将不再控制这个怪兽的运动——我们自己已经写好相关运动的代码了。
    monster.physicsBody.dynamic = YES; // 2
    monster.physicsBody.categoryBitMask = monsterCategory; // 3
    //contactTestBitMask表示与什么类型对象碰撞时，应该通知contact代理。在这里选择炮弹类型。
    monster.physicsBody.contactTestBitMask = projectileCategory; // 4
    //collisionBitMask表示物理引擎需要处理的碰撞事件。在此处我们不希望炮弹和怪物被相互弹开——所以再次将其设置为0。
    monster.physicsBody.collisionBitMask = 0; // 5
}

/*
 这个方法在画面每一帧更新的时候都会被调用 该方法不会被自动调用 需要另外写一个方法来调用它
 */
- (void)updateWithTimeSinceLastUpdate:(CFTimeInterval)timeSinceLast {
    self.lastSpawnTimeInterval += timeSinceLast;
    if (self.lastSpawnTimeInterval > 1) { //一旦该时间大于1 新增一个怪兽
        self.lastSpawnTimeInterval = 0;
        [self addMonster];
    }
}

/*
 Sprite kit在显示每帧的时候都会调用这个的方法
 */
- (void)update:(NSTimeInterval)currentTime {
    
    /* Called before each frame is rendered */
    //下面的代码其实是来自苹果提供的Adventure示例中。该方法会传入当前的时间，在其中，会做一些计算，以确定出上一帧更新的时间。注意，在代码中做了一些合理性的检查，以避免从上一帧更新到现在已经过去了大量时间，并且将间隔重置为1/60秒，避免出现奇怪的行为。
    CFTimeInterval timeSinceLast = currentTime - self.lastUpdateTimeInterval;
    self.lastUpdateTimeInterval = currentTime;
    if (timeSinceLast > 1) {
        timeSinceLast = 1.0 / 60.0;
        self.lastUpdateTimeInterval = currentTime;
    }
    [self updateWithTimeSinceLastUpdate:timeSinceLast];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    [self runAction:[SKAction playSoundFileNamed:@"pew-pew-lei.caf" waitForCompletion:NO]];
    
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInNode:self];
    
    SKSpriteNode *projectile = [SKSpriteNode spriteNodeWithImageNamed:@"projectile"];
    projectile.position = self.player.position;
    
    CGPoint offset = rwSub(location, projectile.position);
    if (offset.x <= 0) {
        return;
    }
    
    [self addChild:projectile];
    
    CGPoint direction = rwNormalize(offset);
    
    CGPoint shootAmount = rwMult(direction, 1000);
    
    CGPoint realDest = rwAdd(shootAmount, projectile.position);
    
    float velocity = 480.0 / 1.0;
    float realMoveDuration = self.size.width / velocity;
    SKAction *actionMove = [SKAction moveTo:realDest duration:realMoveDuration];
    SKAction *actionMoveDone = [SKAction removeFromParent];
    [projectile runAction:[SKAction sequence:@[actionMove, actionMoveDone]]];
    
    //为了更好的效果，炮弹的形状是圆形的
    projectile.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:projectile.size.width/2];
    projectile.physicsBody.dynamic = YES;
    projectile.physicsBody.categoryBitMask = projectileCategory;
    projectile.physicsBody.contactTestBitMask = monsterCategory;
    projectile.physicsBody.collisionBitMask = 0;
    // usesPreciseCollisionDetection属性设置为YES。这对于快速移动的物体非常重要(例如炮弹)，如果不这样设置的话，有可能快速移动的两个物体会直接相互穿过去，而不会检测到碰撞的发生。
    projectile.physicsBody.usesPreciseCollisionDetection = YES;
}
/*
 当炮弹与怪物发生碰撞时会被调用
 */
- (void)projectile:(SKSpriteNode *)projectile didCollideWithMonster:(SKSpriteNode *)monster {
    NSLog(@"Hit");
    [projectile removeFromParent];
    [monster removeFromParent];
    
    self.monstersDestroyed++;
    if (self.monstersDestroyed > 30) {
        SKTransition *reveal = [SKTransition flipHorizontalWithDuration:0.5];
        SKScene * gameOverScene = [[GameOverScene alloc] initWithSize:self.size won:YES];
        [self.view presentScene:gameOverScene transition: reveal];
    }
}

/*
 
 */
- (void)didBeginContact:(SKPhysicsContact *)contact
{
    // 1
    SKPhysicsBody *firstBody, *secondBody;
    
    if (contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask)
    {
        firstBody = contact.bodyA;
        secondBody = contact.bodyB;
    }
    else
    {
        firstBody = contact.bodyB;
        secondBody = contact.bodyA;
    }
    
    // 2
    if ((firstBody.categoryBitMask & projectileCategory) != 0 &&
        (secondBody.categoryBitMask & monsterCategory) != 0)
    {
        [self projectile:(SKSpriteNode *) firstBody.node didCollideWithMonster:(SKSpriteNode *) secondBody.node];
    }
}

@end
