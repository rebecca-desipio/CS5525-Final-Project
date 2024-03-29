# All Code
library(tree)
library(randomForest)  # bootsrap/bagging & random forest
library(class)         # KNN
library(caret)         # SVM
library(glmnet)        # logistic regression

# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #
#                                Decision Trees                                #          
# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #

# Read in and organize data
## -- Read data
heart <- read.csv("heart.csv")
Target <- as.factor(heart$target) # target heart rate 

## -- Split into training and test sets
set.seed(2441139)
train <- sample(1:nrow(heart), 0.75*nrow(heart))
heart.test <- heart[-train, ]
Target.test <- Target[-train]

# ---------------------------------------------------------------------------- #
#                        Fit a Classification Tree                             #          
# ---------------------------------------------------------------------------- #

# Fit a classification tree to the training data
set.seed(2441139)
tree.heart <- tree(Target~. -target, heart, subset=train)
summary(tree.heart)

## -- Plot tree
plot(tree.heart)
text(tree.heart, pretty=1, cex=1)


# Prune the classification tree
set.seed(2441139)
cv.heart <- cv.tree(tree.heart, FUN=prune.misclass)
cv.heart
plot(cv.heart$size, cv.heart$dev, type='b')

set.seed(2441139)
prune.heart <- prune.misclass(tree.heart, best=10)
plot(prune.heart)
text(prune.heart, pretty=1, cex=1)

# Predict using test set and pruned tree. Compare.
tree.pred <- predict(tree.heart, heart.test, type='class')   # test tree
prune.pred <- predict(prune.heart, heart.test, type='class') # pruned tree

table(prune.pred, Target.test)
table(tree.pred, Target.test)

# ---------------------------------------------------------------------------- #
#                                  Bagging                                     #
# ---------------------------------------------------------------------------- #
set.seed(2441139)

# Perform bagging
bag.heart <- randomForest(as.factor(as.character(heart$target))~., data=heart, 
                          subset=train, mtry=ncol(heart)-1, 
                          importance=TRUE)
bag.heart

# Predict on bagged tree
bag.pred <- predict(bag.heart, heart.test, type='class')
table(bag.pred, Target.test)
varImpPlot(bag.heart)

# ---------------------------------------------------------------------------- #
#                                 Random Forest                                #
# ---------------------------------------------------------------------------- #
set.seed(2441139)

# Perform Random Forest
rf.heart <- randomForest(as.factor(as.character(heart$target))~., data=heart, 
                         subset=train, mtry=sqrt(ncol(heart)-1), 
                         ntree=25, importance=TRUE)
rf.heart

# Predict on the forest
rf.pred <- predict(rf.heart, heart.test, type='class')
table(rf.pred, Target.test)
varImpPlot(rf.heart)


# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #
#                      Determine Best Model (Random Forest)                    #
# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #
# Investigate how mtry affect the accuracy
Acc <- rep(0,ncol(heart)-2)
for (m in 1:(ncol(heart)-2)){
  set.seed(2441139)
  rf.heart <- randomForest(as.factor(as.character(heart$target))~., data=heart, 
                           subset=train, mtry=m, 
                           ntree=25)
  rf.pred <- predict(rf.heart, heart.test, type='class')
  t <- table(rf.pred, Target.test)
  acc <- sum(diag(t))/sum(t)
  Acc[m] <- acc
}
mbest <- which(Acc==max(Acc))
plot(1:(ncol(heart)-2), Acc, xlab='mtry', ylab='Accuracy of random forest') # include plot in final submission report


# Now use the best value of m for the random forest
set.seed(2441139)
rf.heart <- randomForest(as.factor(as.character(heart$target))~., data=heart, 
                         subset=train, mtry=mbest, 
                         ntree=25, importance=TRUE)
rf.heart

# Predict on the forest
rf.pred <- predict(rf.heart, heart.test, type='class')
table(rf.pred, Target.test)
varImpPlot(rf.heart)


# ---------------------------------------------------------------------------- #
#                                  KNN                                         #
# ---------------------------------------------------------------------------- #

# K-Nearest Neighbor
cl <- as.factor(heart$target[train])
knn.heart <- knn(heart[train,], heart.test, cl, k = 5, prob=TRUE)
table(knn.heart, Target.test)

# ---------------------------------------------------------------------------- #
#                                  SVM                                         #
# ---------------------------------------------------------------------------- #
set.seed(2441139)

# splitting data into test and train
intrain <- createDataPartition(y = heart$target, p = 0.7, list = F)

training <- heart[intrain,]
testing <- heart[-intrain,]
training[["target"]] <- as.factor(training[["target"]])

dim(training)
dim(testing)

# model training with svm
trctrl <- trainControl(method = "repeatedcv", number = 10, repeats = 3)
svm.mod <- train(target ~ ., data = training, method = "svmLinear",
                 trControl = trctrl,
                 preProcess = c("center", "scale"),
                 tuneLength = 10)
svm.mod

# predction using the above model
svm.pred <- predict(svm.mod, newdata = testing)
svm.pred

# accuracy of the trained model
confusionMatrix(table(svm.pred, testing$target))

# costs for further tuning with 10-fold cross-validation
grid <- expand.grid(C = c(0, 0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 5))

svm.mod.grid <- train(target ~ ., data = training, method = "svmLinear",
                      trControl = trctrl,
                      preProcess = c("center", "scale"),
                      tuneGrid = grid,
                      tuneLength = 10)
svm.mod.grid

# accuracy plot of tuned model
plot(svm.mod.grid)

# prediction using tuned model
svm.pred.grid <- predict(svm.mod.grid, newdata = testing)
svm.pred.grid

# accuracy of the tuned model
confusionMatrix(table(svm.pred.grid, testing$target))

# ---------------------------------------------------------------------------- #
#                         Logistic Regression                                  #
# ---------------------------------------------------------------------------- #
set.seed(2441139)
# Organize data to get training and test data

X <- as.matrix(heart, c("age", "sex", "cp", "trestbps", "chol", "fbs",
                        "restecg", "thalach", "exang", "oldpeak", "slope",
                        "ca", "thal"))
y <- heart$target

n <- nrow(X)
train_rows <- sample(1:n, n * 0.7)

X.train <- X[train_rows,]
X.test <- X[-train_rows,]
y.train <- y[train_rows]
y.test <- y[-train_rows]

dim(X.train)
dim(X.test)
grid <- 10^seq(10, -2, length = 100)

# ---------------------------------------------------------------------------- #
#                                    Lasso                                     #
# ---------------------------------------------------------------------------- #

# lasso model
lasso.mod <- glmnet(X.train, as.factor(y.train), alpha = 1, lambda = grid,
                    family = "binomial")
plot(lasso.mod, xvar = "lambda", label = T)

# cross-validation for lambda
cv.out <- cv.glmnet(X.train, as.factor(y.train), family = "binomial", alpha = 1,
                    type.measure = "class")
bestlam <- cv.out$lambda.min
bestlam

# coefficients of the best model
best.lasso.mod <- glmnet(X.train, as.factor(y.train), alpha = 1, lambda = bestlam,
                         family = "binomial")
coef(best.lasso.mod)

# test error
lasso.pred <- predict(best.lasso.mod, newx = X.test, s = bestlam)
lasso.mse <- mean((lasso.pred - y.test)^2)
lasso.mse

# non-zero coefficients
lasso.coef <- predict(best.lasso.mod, type = "coefficients", s = bestlam)
lasso.coef <- lasso.coef[which(lasso.coef != 0)]
lasso.coef

# ---------------------------------------------------------------------------- #
#                                 Elastic Net                                  #
# ---------------------------------------------------------------------------- #
# elastic net model
en.mod <- glmnet(X.train, as.factor(y.train), alpha = 0.5, lambda = grid,
                 family = "binomial")
plot(en.mod, xvar = "lambda", label = T)

# cross-validation for lambda (with a fixed alpha)
cv.out <- cv.glmnet(X.train, y.train, alpha = 0.5)
bestlam <- cv.out$lambda.min

# coefficients of the best model
best.en.mod <- glmnet(X.train, as.factor(y.train), alpha = 0.5, lambda = bestlam,
                      family = "binomial")
coef(best.en.mod)

# test error
en.pred <- predict(best.en.mod, s = bestlam, newx = X.test)
en.mse <- mean((en.pred - y.test)^2)
en.mse

# non-zero coefficients
en.coef <- predict(best.en.mod, type = "coefficients", s = bestlam)
en.coef <- en.coef[which(en.coef != 0)]
en.coef
```