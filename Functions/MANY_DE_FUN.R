#code came from E:\RNAseqProject\NEWPROJECT_PAPERS\Classical paper\DE_Comparison of methods to detect differentially
###SCnorm MAST########
library(MAST)
library(reshape2)
library(DESeq)
library(limma)
library(edgeR)
######ROC_fun#############
ROC_fun<-function(list_pref,vec_auc,method_vec,col_vec,MAIN='',cex=1,lwd=1,cex.lab=1,cex.axis=1,cex.legend=1,line=2.5){
    par(cex.axis=cex.axis)
  plot(list_pref[[1]],col=col_vec[1],lwd=lwd,cex=cex,cex.lab=cex.lab,cex.main=cex,cex.axis=cex.axis,xlab='',ylab='')

  for(i in 2:length(list_pref))
  {
    plot( list_pref[[i]],col=col_vec[i],add=T,lwd=lwd,cex=cex,cex.lab=cex.lab,cex.main=cex,cex.axis=cex.axis,xlab='',ylab='')
  }
  
 # plot(list_pref[[1]],xlab='',ylab='')
  
  title('',xlab='False positive rate',ylab='True positive rate',cex.main=cex,line=line,cex.lab=cex.lab)
  
  
  
  ll<-NULL
  for(i in 1:length(list_pref)){
    ll<-c(ll,paste(method_vec[i],round(vec_auc[i],4)))
  }

  legend("bottomright",legend=ll,cex=cex.legend,bty = "n",text.col = col_vec,title.col=1,title=MAIN)
  
  
}


SCnorm_runMAST2 <- function(Data, NumCells) {
    if(length(dim(Data))==2){
        resultss<-SCnorm_runMAST(Data, NumCells)
    } else if(length(dim(Data))==3){
        
        library(foreach)
  
        resultss<- foreach(sampleind=1:dim(Data)[3],.combine=cbind)%do%{
            print(sampleind)
            
           qq<-SCnorm_runMAST(Data[,,sampleind], NumCells)
           return(qq$adjpval)
        }
        
        
        
    }
    
   return(resultss) 
}

########SCnorm_runMAST3##########
SCnorm_runMAST3 <- function(Data, NumCells) {
    
    #if(class(Data)=='list')
    
    
    
    
    
    
    
    if(length(dim(Data))==2){
        resultss<-SCnorm_runMAST(Data, NumCells)
    } else if(length(dim(Data))==3){
        
        library(foreach)
        # library(doSNOW)
        # library(parallel)
        # 
        # cluster = makeCluster(5, type = "SOCK")
        # registerDoSNOW(cluster)
        # getDoParWorkers()
        # 
        # iterations <- dim(Data)[3]
        # pb <- txtProgressBar(max = iterations, style = 3)
        # progress <- function(n) setTxtProgressBar(pb, n)
        # opts <- list(progress = progress)
        
        
        
        #resultss<- foreach(sampleind=1:dim(Data)[3],.combine=cbind,.options.snow = opts, .export=c('SCnorm_runMAST'), .packages=c('MAST','reshape2'))%dopar%{
        resultss<- foreach(sampleind=1:dim(Data)[3],.combine=cbind)%do%{
            print(sampleind)
            
            qq<-SCnorm_runMAST(Data[,,sampleind], NumCells)
            return(qq$adjpval)
        }
        
        # close(pb)
        # stopCluster(cluster)
        
        
        
    }
    
    return(resultss) 
}

SCnorm_runMAST <- function(Data, NumCells) {

  NA_ind<-which(rowSums(Data)==0)



  Data = as.matrix(log2(Data+1))


  G1<-Data[,seq(1,NumCells[1])]
  G2<-Data[,-seq(1,NumCells[1])]

  qq_temp<- rowMeans(G2)-rowMeans(G1)
  qq_temp[NA_ind]=NA

  numGenes = dim(Data)[1]
  datalong = melt(Data)
  Cond = c(rep("c1", NumCells[1]*numGenes), rep("c2", NumCells[2]*numGenes))
  dataL = cbind(datalong, Cond)
  colnames(dataL) = c("gene","cell","value","Cond")
  dataL$gene = factor(dataL$gene)
  dataL$cell = factor(dataL$cell)
  vdata = FromFlatDF(dataframe = dataL, idvars = "cell", primerid = "gene", measurement = "value",  id = numeric(0), cellvars = "Cond", featurevars = NULL,  phenovars = NULL)



  #zlm.output = zlm.SingleCellAssay(~ Cond, vdata, method='glm', ebayes=TRUE)
zlm.output = zlm(~ Cond, vdata, method='glm', ebayes=TRUE)

  # logFC_re<-logFC(zlm.output)
  # qq<-as.data.frame(logFC_re)
  # colnames(qq)<-names(logFC_re)
  # qq<-qq[rownames(Data),]


  zlm.lr = lrTest(zlm.output, 'Cond')

  gpval = zlm.lr[,,'Pr(>Chisq)']
  adjpval = p.adjust(gpval[,1],"BH") ## Use only pvalues from the continuous part.

  adjpval = adjpval[rownames(Data)]
  #return(list(adjpval=adjpval, logFC_re= qq$logFC))
  return(list(adjpval=adjpval, logFC_re=qq_temp))
}




#######MAST########
Run_MAST = function(rawData ,gr1,gr2,log=F ){

  # Loading the libraries:

  #library("MAST", lib.loc="~/R/win-library/3.1")
  library(MAST)
  library(data.table)
  library(plyr)

  data = as.matrix(rawData)
  th = thresholdSCRNACountMatrix(t(data), conditions = c(rep(1,gr1),rep(2,gr2)), nbin=40,data_log = log)
  thdata = th$counts_threshold

  # Drop genes that are never detected:
  #cs = apply(thdata, 2, sum)
  #thdata = thdata[,cs>0]

  # Drop cells with too few detections
  #rs = apply(thdata, 1, sum)
  #thdata = thdata[rs>log2(1e4),]

  # Drop out cells with too low portion of measured genes

  #mp = apply(thdata, 1, function(x){
  #  det = as.numeric(x)
  #  proportion = sum(det>0)
  #})

  #quan = quantile(mp)
  #iqr = 1.5*(quan["75%"]-quan["25%"])
  #outliers = mp<(min(mp)-iqr)
  #thdata = thdata[!outliers,]

  fData = data.frame(primerid=colnames(thdata))
  cData = data.frame(Population=c(rep("G1",gr1), rep("G2",gr2)), wellKey=rownames(thdata))

  sca = FromMatrix(t(thdata), cData, fData,class="SingleCellAssay")



  modelfit = zlm(~ Population, sca)
  lrt = lrTest(modelfit, "Population") # returns 3 dimensonal array
  #save(list=c("sca", "modelfit", "lrt", "thdata"), file="MASTvariables_Islam.RData")

  hurdle = lrt[,"hurdle", ]
  pvaluesh = hurdle[,"Pr(>Chisq)"] # Named vector


  results = data.frame(pvaluesh)
  colnames(results) = c("P_hurdle")
  #write.table(results, file="MAST_Islam.txt", sep="\t", quote=F)
  return(results)
}




# Running ROTS:#########
TMMnormalization <- function(countTable){
  ## TMM normalization based on edgeR package:
  require("edgeR")

  nf=calcNormFactors(countTable ,method= "TMM")
  nf= colSums(countTable)*nf
  scalingFactors = nf/mean(nf)
  countTableTMM <- t(t(countTable)/scalingFactors)

  return(countTableTMM)

}
Run_ROTS = function(rawData, gr1, gr2, B, K , FDR,log=F,tmm=F){



  # rawData is the input raw count table
  # gr1 is the number of cells in condition 1
  # gr2 is the number of cells in condition 2
  # B is the number of bootstraps
  # k is the number of top ranked genes
  # FDR is the fdr threshold for the final detections

  FilteredData = rawData

  require(ROTS)
  if(tmm){
    FilteredData = TMMnormalization(rawData)
  }

  #FilteredData = rawData

  #rawData<-log2(rawData+1)
  # TMM normalization over the raw count matrix:

  #TMM_Filtered_Data = TMMnormalization(FilteredData)

  # Running ROTS over the filtered and normalized data:

  #ROTS_filtered_TMM = ROTS(data = TMM_Filtered_Data, groups = c(rep(0,as.numeric(gr1)),rep(1,as.numeric(gr2))) , B = 1000, K = 6000 )
  ROTS_filtered_TMM = ROTS(data = FilteredData, groups = c(rep(0,as.numeric(gr1)),rep(1,as.numeric(gr2))) , B =B, K =K ,log=log)

  # Rows/genes with FDR smaller than the desired threshold:

  ROTS_results = summary(ROTS_filtered_TMM , fdr = 1)

  #save(ROTS_filtered_TMM , ROTS_results , file = "ROTS_results.RData")

  return(ROTS_results)

}

########DESeq#########
Run_DESeq = function(rawData , gr1 , gr2){

  #require("DESeq")

  # First the genes with 0 value for all the cells were filtered out:

  filtered = apply(rawData,1, function(x) {if(all(x == 0)) return (FALSE) else return(TRUE)})

  FilteredData = rawData[filtered,]

  # Defining the sample's description and conditions:

  dataPack = data.frame(row.names= colnames(FilteredData), condition = c(rep("GR1",gr1) ,rep("GR2",gr2)))

  conds <- factor (c(rep("GR1",gr1) ,rep("GR2",gr2)))

  # Initializing a CountDataSet (DESeq data structure for count matrix):

  cds <- newCountDataSet(FilteredData, conds)

  # DESeq normaliztion:

  cds <- estimateSizeFactors (cds)
  #print (sizeFactors(cds))
  #print (head(counts(cds, normalized = TRUE)))

  # Variance estimation:

  cds <- estimateDispersions (cds)

  #print(str(fitInfo(cds)))

  # Negative binomial test:

  DESeq_results = nbinomTest(cds, "GR1", "GR2")

  #save(DESeq_results, file ="DESeq_results.RData")

}

Run_DESeq_ori = function(rawData , gr1 , gr2){

  require("DESeq")

  # First the genes with 0 value for all the cells were filtered out:

  # filtered = apply(rawData,1, function(x) {if(all(x == 0)) return (FALSE) else return(TRUE)})
  #
  # FilteredData = rawData[filtered,]
  FilteredData =rawData
  # Defining the sample's description and conditions:

  dataPack = data.frame(row.names= colnames(FilteredData), condition = c(rep("GR1",gr1) ,rep("GR2",gr2)))

  conds <- factor (c(rep("GR1",gr1) ,rep("GR2",gr2)))

  # Initializing a CountDataSet (DESeq data structure for count matrix):

  cds <- newCountDataSet(FilteredData, conds)

  # DESeq normaliztion:

  cds <- estimateSizeFactors (cds)
  print (sizeFactors(cds))
  print (head(counts(cds, normalized = TRUE)))

  # Variance estimation:

  cds <- estimateDispersions (cds)

  print(str(fitInfo(cds)))

  # Negative binomial test:

  DESeq_results = nbinomTest(cds, "GR1", "GR2")

  # save(DESeq_results, file ="DESeq_results.RData")
  return(DESeq_results)

}


######scde#######

Run_scde = function(rawData){

  #library("scde", lib.loc="~/R/win-library/3.1")

  # clean up the dataset
  cd = rawData
  cd = cd[rowSums(cd)>0, ]
  #cd = cd[, colSums(cd)>1e4]

  # factor determining cell types:
  sg <- factor(gsub("(MEF|ESC).*", "\\1", colnames(cd)), levels = c("ESC", "MEF"))

  # the group factor should be named accordingly
  names(sg) <- colnames(cd)
  table(sg)

  # calculate models (slow)
  o.ifm = scde.error.models(counts = cd, groups = sg, n.cores = 6, threshold.segmentation = TRUE, save.crossfit.plots = FALSE, save.model.plots = FALSE, verbose = 1)

  # setwd("") # Where you want the results
  #save("o.ifm", file="oifmRaw.RData")

  # filter out cells that don't show positive correlation with
  # the expected expression magnitudes (very poor fits)
  valid.cells = o.ifm$corr.a > 0
  #table(valid.cells)

  o.ifm = o.ifm[valid.cells, ]

  # estimate gene expression prior
  o.prior = scde.expression.prior(models = o.ifm, counts = cd, length.out = 400, show.plot = FALSE)

  #save(list=c("o.ifm", "o.prior"), file="VariablesIslam.RData")                # define two groups of cells
  groups = factor(gsub("(MEF|ESC).*", "\\1", rownames(o.ifm)), levels  =  c("ESC", "MEF"))
  names(groups) = row.names(o.ifm)
  # run differential expression tests on all genes.
  ediff = scde.expression.difference(o.ifm, cd, o.prior, groups  =  groups, n.randomizations  =  100, n.cores  =  1, verbose  =  1)

  # write out a table with all the results, showing most significantly different genes (in both directions) on top
 # write.table(ediff[order(abs(ediff$Z), decreasing = TRUE), ], file = "IslamResults.txt", row.names = TRUE, col.names = TRUE, sep = "\t", quote = FALSE)
  qq<-ediff[order(abs(ediff$Z), decreasing = TRUE), ]
  return(qq)

}

#########limma#####

Run_Limma = function(rawData, gr1, gr2){

  #require(limma)

  filtered = apply(rawData,1, function(x) {if(all(x == 0)) return (FALSE) else return(TRUE)})
  FilteredData = rawData[filtered,]

  # Samples' conditions:
  mType <- factor (c(rep("GR1",gr1) ,rep("GR2",gr2)))

  # Normalization factors from edgeR TMM method:

  nf <- calcNormFactors(FilteredData)

  design <- model.matrix(~mType)

  # Voom transformation for RNA-seq data:
  y <- voom (FilteredData, design, lib.size = colSums(FilteredData)*nf)

  # Linear modeling:

  fit <- lmFit(y,design)

  fit <- eBayes(fit)

  # Summary of the results:

  Limma_results <- topTable(fit,coef=2,n=nrow(fit))


  #save(Limma_results , file = "Limma_results.RData")
  return(Limma_results)
}





Run_Limma_ori = function(rawData, gr1, gr2){

  require(limma)

  # filtered = apply(rawData,1, function(x) {if(all(x == 0)) return (FALSE) else return(TRUE)})
  # FilteredData = rawData[filtered,]
  #
  FilteredData =rawData

  # Samples' conditions:
  mType <- factor (c(rep("GR1",gr1) ,rep("GR2",gr2)))

  # Normalization factors from edgeR TMM method:

  nf <- calcNormFactors(FilteredData)

  design <- model.matrix(~mType)

  # Voom transformation for RNA-seq data:
  y <- voom (FilteredData, design, lib.size = colSums(FilteredData)*nf)

  # Linear modeling:

  fit <- lmFit(y,design)

  fit <- eBayes(fit)

  # Summary of the results:

  Limma_results <- topTable(fit,coef=2,n=nrow(fit))
  Limma_results<-Limma_results[rownames(rawData),]

  #save(Limma_results , file = "Limma_results.RData")
  return(Limma_results)

}


#####simulation for SAVER#########
library(SAVER)
library(abind)
CONDITION=c(rep(1,100),rep(2,100))
saver_norm_fun<-function(RAW_DATA,CONDITION,savepath){
    
    
    saver_temp1<-saver(x=RAW_DAT[,CONDITION==1])
    saver_temp2<-saver(x=RAW_DAT[,CONDITION==2])
    
    saver_array1<-sample.saver(x=saver_temp1,rep=10)
    saver_array2<-sample.saver(x=saver_temp2,rep=10)
    
    saver_out<-cbind(saver_temp1$estimate,saver_temp2$estimate)
    M_saver<-SCnorm_runMAST(Data=saver_out,NumCells = c(100,100))
    
    
    saver_array1<-abind(saver_array1,along=3)
    saver_array2<-abind(saver_array2,along=3)
    saver_array1[is.na(saver_array1)]<-0
    saver_array2[is.na(saver_array2)]<-0
    
    
    qq<-abind(saver_array1,saver_array2,along=2)
    M_saver10<-SCnorm_runMAST3(Data=qq,NumCells =c(100,100))
    rm(qq)
    save(saver_temp1,saver_temp2,saver_out,M_saver,saver_array1,saver_array2,M_saver10,file=savepath)
    return(list(saver_temp1=saver_temp1,saver_temp2=saver_temp2,saver_out=saver_out,M_saver=M_saver,saver_array1=saver_array1,saver_array2=saver_array2,M_saver10=M_saver10))
}

saver_norm_fun2<-function(RAW_DATA,CONDITION,savepath){
    
    
    saver_temp<-saver(x=RAW_DAT)
    
    saver_array<-sample.saver(x=saver_temp,rep=10)
    
    saver_out<-saver_temp$estimate
    M_saver<-SCnorm_runMAST(Data=saver_out,NumCells = c(100,100))
    
    
    saver_array<-abind(saver_array,along=3)
    saver_array[is.na(saver_array)]<-0
    
    M_saver10<-SCnorm_runMAST3(Data=saver_array,NumCells = c(100,100))
    rm(qq)
    save(saver_out,M_saver,saver_array,M_saver10,file=savepath)
    return(list(saver_out=saver_out,M_saver=M_saver,saver_array=saver_array,M_saver10=M_saver10))
}
